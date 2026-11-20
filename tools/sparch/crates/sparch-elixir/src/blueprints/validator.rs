//! One Vex validator per invariant/constraint the model resolved, plus
//! the `unique-slug` and `domain-object-exists` examples.
//!
//! Three shapes, decided by the invariant pattern that claimed the rule:
//!
//! * `unique-<field>` invariants → uniqueness against the internal API
//!   accessor, tolerating the object that already owns the value (edit case)
//! * `<domain_object>-exists` command constraints → existence check by id,
//!   guarded by `Sportipedia.Support.Validators.UuidValidator.valid_uuid?/1`
//!   so no value that cannot denote the resource (nil, blank, malformed)
//!   reaches `Repo.get/2` — those raise, and a raise answers the client a 500
//! * any other rule naming a field of the citizen (cross-field or
//!   cross-aggregate) → a scaffold the operator implements
//!
//! This blueprint is not a generator: the command that validates with the
//! validator owns it (the way it owns its router registration), so it lives
//! in the registry's `by_name` only, never in `all()`, and reaches the
//! closure sweep inside the command's dependency expansion. Generating a
//! validator generates the internal API it calls and, for a unique field,
//! the lookup query that accessor reads through. Validators are tested as
//! part of the command's tests, so this blueprint contributes no test file
//! of its own.

use std::collections::HashSet;

use sparch_model::ElementKind;
use sparch_model::invariants::{Validator, ValidatorKind};
use sparch_model::placeholders::Vars;

use crate::blueprints::internal_api::InternalApi;
use crate::context::Context;
use crate::elixir::Rank;
use crate::plan::{Blueprint, Dependency, FilePlan, Placement, Unit, UnitId};

pub(crate) const PATH: &str = "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/validators/<_validator>.ex";
const MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Validators.<Validator>";
const INTERNAL_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal";
/// the total UUID guard the exists shape puts in front of the by-id lookup
const UUID_VALIDATOR: &str = "Sportipedia.Support.Validators.UuidValidator";

pub struct ValidatorBlueprint;

impl ValidatorBlueprint {
    /// The validator module's file path (used as a `requires` gate).
    pub fn module_file(ctx: &Context, validator: &Validator) -> String {
        ctx.render_or_panic_with(PATH, &validator_vars(&validator.snake))
    }

    /// The validator module's dotted name in `ctx` — the full name the
    /// command aliases and its `validates` lines reference through it.
    pub fn module_name(ctx: &Context, validator: &Validator) -> String {
        ctx.render_or_panic_with(MODULE, &validator_vars(&validator.module))
    }
}

fn validator_vars(value: &str) -> Vars {
    let mut vars = Vars::new();
    vars.insert("validator".to_string(), value.to_string());
    vars
}

impl Blueprint for ValidatorBlueprint {
    fn name(&self) -> &'static str {
        "validator"
    }

    /// The validator belongs to the command that validates with it; it is
    /// never addressed as a generator.
    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command]
    }

    /// A validator of an example shape is a call into the internal API;
    /// scaffolded rules call no query.
    fn dependencies(&self, ctx: &Context) -> Vec<Dependency> {
        if ctx.validators.iter().any(|v| v.kind != ValidatorKind::Rule) {
            vec![Dependency {
                blueprint_name: "internal_api",
                element: ctx.element.clone(),
            }]
        } else {
            Vec::new()
        }
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(PATH, "Vex rules per invariant")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        // One rule is one validator module even when it names several
        // fields: the descriptors multiply per field, the file does not.
        let mut seen: HashSet<String> = HashSet::new();
        ctx.validators
            .iter()
            .filter(|v| seen.insert(v.snake.clone()))
            .map(|validator| {
                FilePlan::new(
                    ctx.render_or_panic_with(PATH, &validator_vars(&validator.snake)),
                    Some(ctx.render_or_panic_with(MODULE, &validator_vars(&validator.module))),
                    units(validator, ctx),
                )
            })
            .collect()
    }
}

// ------------------------------------------------------------------- units

fn units(validator: &Validator, ctx: &Context) -> Vec<Unit> {
    let internal = ctx.render_or_panic(INTERNAL_MODULE);
    let gate = internal_gate(validator, ctx);

    let mut units = vec![
        // a validator of an example shape is a call into the internal API:
        // with no internal API to alias, nothing is placeable and the file
        // stays away
        Unit {
            id: UnitId::Moduledoc,
            check: Box::new(|f| f.has_moduledoc()),
            render: {
                let doc = doc(validator, ctx);
                Box::new(move || format!("@moduledoc \"\"\"\n{doc}\n\"\"\""))
            },
            requires: gate.clone(),
            place: Placement::Head {
                rank: Rank::Moduledoc,
                alias_sort_key: None,
            },
            stale: None,
        },
        Unit {
            id: UnitId::Use("Vex.Validator".into()),
            check: Box::new(|f| f.has_use("Vex.Validator")),
            render: Box::new(|| "use Vex.Validator".to_string()),
            requires: gate.clone(),
            place: Placement::Head {
                rank: Rank::Use,
                alias_sort_key: None,
            },
            stale: None,
        },
    ];

    // scaffolded rules call no query; the example shapes need the internal
    // API
    if validator.kind != ValidatorKind::Rule {
        let check_module = internal.clone();
        let render = alias_lines(validator, ctx);
        units.push(Unit {
            id: UnitId::Alias(internal.clone()),
            check: Box::new(move |f| f.has_alias(&check_module)),
            render: Box::new(move || render.clone()),
            requires: gate.clone(),
            place: Placement::Head {
                rank: Rank::Alias,
                alias_sort_key: Some(internal.clone()),
            },
            stale: None,
        });
    }

    units.push({
        let render = def_block(validator, ctx);
        Unit {
            id: UnitId::Def("validate".into(), 2),
            check: Box::new(|f| f.has_def("validate", 2)),
            render: Box::new(move || render.clone()),
            requires: gate,
            place: Placement::BeforeHelpers,
            stale: None,
        }
    });

    units
}

/// The internal API module must exist before the alias/lookup may appear.
/// A scaffolded rule names no query, so its units carry no gate at all.
fn internal_gate(validator: &Validator, ctx: &Context) -> Vec<(String, String)> {
    if validator.kind == ValidatorKind::Rule {
        return Vec::new();
    }
    vec![(
        InternalApi::module_file(ctx),
        "internal API not generated (sparch internal_api)".to_string(),
    )]
}

// ---------------------------------------------------------------- rendering

fn doc(validator: &Validator, ctx: &Context) -> String {
    match validator.kind {
        ValidatorKind::Unique => format!(
            "Validates that a {} {} is unique within the {}.",
            ctx.constituent, validator.field, ctx.composite
        ),
        ValidatorKind::Exists => format!(
            "Validates that a {} exists.\n\nThe rule is asked of an address: only a value that can denote a\n{} is looked up. A malformed id addresses nothing, so no\n{} can hold it, and the answer is the one the pattern gives\nfor an unknown id. An absent or blank id is not this rule's to answer —\n`presence` owns it, and the command's `validates` line keeps this validator\noff it.",
            ctx.constituent, ctx.constituent, ctx.constituent
        ),
        ValidatorKind::Rule => format!(
            "Validates the '{}' rule: {}",
            validator.name,
            validator.rule.as_deref().unwrap_or("")
        ),
    }
}

/// The `@doc`/`@spec` header over the body; the exists shape's spec takes
/// `term()` because the value arrives straight off the request.
fn def_block(validator: &Validator, ctx: &Context) -> String {
    let body = body(validator, ctx).trim_end().to_string();
    if validator.kind == ValidatorKind::Exists {
        return format!(
            "@doc \"\"\"\nValidates the given {} value.\n\"\"\"\n# `term()`, not `String.t()`: the value reaches here straight off the request,\n# and a request can name an id with anything at all.\n@spec validate(term(), map()) :: :ok | {{:error, :not_found}}\n{body}",
            validator.field
        );
    }
    format!(
        "@doc \"\"\"\nValidates the given {} value.\n\"\"\"\n@spec validate(String.t(), map()) :: :ok | {{:error, term()}}\n{body}",
        validator.field
    )
}

/// The three example shapes.
fn body(validator: &Validator, ctx: &Context) -> String {
    let internal = format!("{}Internal", Context::pascal(&ctx.constituent));
    let do_ = &ctx.constituent;
    let field = &validator.field;
    match validator.kind {
        ValidatorKind::Unique => {
            let helper = format!("{field}_belongs_to_{do_}?");
            format!(
                "def validate(value, context) do\n  with {do_} <- {internal}.{do_}_by_{field}(value),\n       false <- is_nil({do_}),\n       false <- {helper}({do_}, context) do\n    {{:error, :{field}_exists}}\n  else\n    _ -> :ok\n  end\nend\n\ndefp {helper}({do_}, context) do\n  id = Map.get(context, :id)\n\n  id == {do_}.id\nend"
            )
        }
        ValidatorKind::Exists => format!(
            "def validate({field}, _context) do\n  # The existence check is a round trip on the primary key, and `Repo.get/2`\n  # raises on a value it cannot put in that clause: nil, a blank string, an\n  # id of the wrong shape. A raise here reaches the client as 500. A\n  # value that cannot denote the resource denotes no resource — the pattern's\n  # own verdict for an unknown id, given without leaving the process.\n  if UuidValidator.valid_uuid?({field}) do\n    case {internal}.{do_}_by_{field}({field}) do\n      nil -> {{:error, :not_found}}\n      _{do_} -> :ok\n    end\n  else\n    {{:error, :not_found}}\n  end\nend"
        ),
        ValidatorKind::Rule => format!(
            "def validate(_value, _context) do\n  raise \"TODO: implement the {} validator (see the domain model rule)\"\nend",
            validator.name
        ),
    }
}

/// The internal API alias, with the UUID guard's alias travelling inside
/// the exists shape on purpose: a validator file that predates the guard
/// already carries the internal alias, so this unit counts as present and
/// the old file stays untouched — as a unit of its own, the alias would be
/// appended to every old file, unused by the unguarded body still sitting
/// there.
fn alias_lines(validator: &Validator, ctx: &Context) -> String {
    let internal = ctx.render_or_panic(INTERNAL_MODULE);
    if validator.kind == ValidatorKind::Exists {
        return format!("alias {internal}\nalias {UUID_VALIDATOR}");
    }
    format!("alias {internal}")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use crate::elixir::ElixirFile;
    use sparch_model::Model;
    use std::path::PathBuf;

    fn ctx_for(name: &str) -> Context {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model
            .resolve(name, &[ElementKind::Command])
            .expect("fixture command");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn validator_by_snake(ctx: &Context, snake: &str) -> Validator {
        ctx.validators
            .iter()
            .find(|v| v.snake == snake)
            .unwrap_or_else(|| panic!("no {snake} validator"))
            .clone()
    }

    fn plan(ctx: &Context, snake: &str) -> FilePlan {
        ValidatorBlueprint
            .plans(ctx)
            .into_iter()
            .find(|p| p.path.ends_with(&format!("{snake}.ex")))
            .expect("plan for the validator")
    }

    fn render(units: &[Unit], label: &str) -> String {
        let unit = units
            .iter()
            .find(|u| u.id.label() == label)
            .unwrap_or_else(|| panic!("no unit {label}"));
        (unit.render)()
    }

    #[test]
    fn paths_and_modules_render_as_the_model_expects() {
        let ctx = ctx_for("create-widget");
        let unique = validator_by_snake(&ctx, "unique_slug");
        assert_eq!(
            ValidatorBlueprint::module_file(&ctx, &unique),
            "services/api/lib/sportipedia/catalog/equipment/widget/validators/unique_slug.ex"
        );
        assert_eq!(
            ValidatorBlueprint::module_name(&ctx, &unique),
            "Sportipedia.Catalog.Equipment.Widget.Validators.UniqueSlug"
        );
        let plan = plan(&ctx, "unique_slug");
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.Catalog.Equipment.Widget.Validators.UniqueSlug")
        );
        assert!(plan.unit_created);
    }

    #[test]
    fn one_rule_is_one_file_even_over_several_fields() {
        // at-most-one-owner names coachId AND teamId — two descriptors,
        // one validator module
        let ctx = ctx_for("create-widget");
        let plans = ValidatorBlueprint.plans(&ctx);
        let paths: Vec<String> = plans.iter().map(|p| p.path.clone()).collect();
        assert_eq!(
            paths,
            vec![
                "services/api/lib/sportipedia/catalog/equipment/widget/validators/at_most_one_owner.ex",
                "services/api/lib/sportipedia/catalog/equipment/widget/validators/unique_slug.ex",
            ]
        );
    }

    #[test]
    fn the_unique_shape_carries_a_body_that_tolerates_the_owning_record() {
        let ctx = ctx_for("create-widget");
        let units = plan(&ctx, "unique_slug").units;
        assert_eq!(
            render(
                &units,
                "alias Sportipedia.Catalog.Equipment.Widget.WidgetInternal"
            ),
            "alias Sportipedia.Catalog.Equipment.Widget.WidgetInternal"
        );
        assert_eq!(
            render(&units, "validate/2"),
            "@doc \"\"\"\nValidates the given slug value.\n\"\"\"\n@spec validate(String.t(), map()) :: :ok | {:error, term()}\ndef validate(value, context) do\n  with widget <- WidgetInternal.widget_by_slug(value),\n       false <- is_nil(widget),\n       false <- slug_belongs_to_widget?(widget, context) do\n    {:error, :slug_exists}\n  else\n    _ -> :ok\n  end\nend\n\ndefp slug_belongs_to_widget?(widget, context) do\n  id = Map.get(context, :id)\n\n  id == widget.id\nend"
        );
        assert_eq!(
            render(&units, "moduledoc"),
            "@moduledoc \"\"\"\nValidates that a widget slug is unique within the equipment.\n\"\"\""
        );
    }

    #[test]
    fn the_exists_shape_guards_the_lookup_with_the_uuid_validator() {
        let ctx = ctx_for("archive-widget");
        let units = plan(&ctx, "widget_exists").units;
        // the guard's alias travels inside the internal-API alias unit
        assert_eq!(
            render(
                &units,
                "alias Sportipedia.Catalog.Equipment.Widget.WidgetInternal"
            ),
            "alias Sportipedia.Catalog.Equipment.Widget.WidgetInternal\nalias Sportipedia.Support.Validators.UuidValidator"
        );
        let def = render(&units, "validate/2");
        assert!(
            def.contains("@spec validate(term(), map()) :: :ok | {:error, :not_found}"),
            "the total guard types the value as term():\n{def}"
        );
        assert!(
            def.contains(
                "if UuidValidator.valid_uuid?(id) do\n    case WidgetInternal.widget_by_id(id) do"
            ),
            "the lookup runs only past the guard:\n{def}"
        );
        assert!(
            render(&units, "moduledoc")
                .starts_with("@moduledoc \"\"\"\nValidates that a widget exists.\n"),
            "the exists doc:\n{}",
            render(&units, "moduledoc")
        );
    }

    #[test]
    fn the_rule_shape_scaffolds_and_names_no_query() {
        let ctx = ctx_for("create-widget");
        let plan = plan(&ctx, "at_most_one_owner");
        // no alias unit at all — a scaffold calls nothing
        let labels: Vec<String> = plan.units.iter().map(|u| u.id.label()).collect();
        assert_eq!(labels, vec!["moduledoc", "use Vex.Validator", "validate/2"]);
        for unit in &plan.units {
            assert!(unit.requires.is_empty(), "a rule calls no citizen");
        }
        assert_eq!(
            render(&plan.units, "validate/2"),
            "@doc \"\"\"\nValidates the given coachId value.\n\"\"\"\n@spec validate(String.t(), map()) :: :ok | {:error, term()}\ndef validate(_value, _context) do\n  raise \"TODO: implement the at-most-one-owner validator (see the domain model rule)\"\nend"
        );
        assert_eq!(
            render(&plan.units, "moduledoc"),
            "@moduledoc \"\"\"\nValidates the 'at-most-one-owner' rule: A widget is owned by at most one coach (either coachId or teamId, not both)\n\"\"\""
        );
    }

    #[test]
    fn example_shapes_wait_for_the_internal_api() {
        // edit-widget's rule set carries both example shapes: the unique
        // field and the by-id existence check
        let ctx = ctx_for("edit-widget");
        let gate = vec![(
            "services/api/lib/sportipedia/catalog/equipment/widget/internal.ex".to_string(),
            "internal API not generated (sparch internal_api)".to_string(),
        )];
        for snake in ["unique_slug", "widget_exists"] {
            let plan = plan(&ctx, snake);
            for unit in &plan.units {
                assert_eq!(unit.requires, gate, "{} of {snake}", unit.id.label());
            }
        }
    }

    #[test]
    fn a_non_rule_validator_pulls_the_internal_api_as_dependency() {
        let ctx = ctx_for("create-widget");
        let deps = ValidatorBlueprint.dependencies(&ctx);
        assert_eq!(deps.len(), 1);
        assert_eq!(deps[0].blueprint_name, "internal_api");
        assert_eq!(deps[0].element.name, "create-widget");

        // catalog-apparatus rules (`unique-equipment-slug`, `valid-slug`)
        // both fall to the field-rule pattern — a command whose every
        // validator scaffolds calls no query and pulls no internal API
        let only_rules = ctx_for("catalog-apparatus");
        assert!(
            only_rules
                .validators
                .iter()
                .all(|v| v.kind == ValidatorKind::Rule),
            "the corpus promise: {:?}",
            only_rules.validators
        );
        let deps = ValidatorBlueprint.dependencies(&only_rules);
        assert!(deps.is_empty(), "rule-only validators pull nothing");
    }

    #[test]
    fn the_finished_validator_file_is_fully_present() {
        // the finished file, parsed back: every unit reads present
        let text = "defmodule Sportipedia.Catalog.Equipment.Widget.Validators.UniqueSlug do\n  @moduledoc \"\"\"\n  Validates that a widget slug is unique within the equipment.\n  \"\"\"\n  use Vex.Validator\n  alias Sportipedia.Catalog.Equipment.Widget.WidgetInternal\n\n  @doc \"\"\"\n  Validates the given slug value.\n  \"\"\"\n  @spec validate(String.t(), map()) :: :ok | {:error, term()}\n  def validate(value, context) do\n    with widget <- WidgetInternal.widget_by_slug(value),\n         false <- is_nil(widget),\n         false <- slug_belongs_to_widget?(widget, context) do\n      {:error, :slug_exists}\n    else\n      _ -> :ok\n    end\n  end\n\n  defp slug_belongs_to_widget?(widget, context) do\n    id = Map.get(context, :id)\n\n    id == widget.id\n  end\nend\n";
        let file = ElixirFile::parse(text);
        let ctx = ctx_for("create-widget");
        for unit in &plan(&ctx, "unique_slug").units {
            assert!((unit.check)(&file), "{} must read present", unit.id.label());
        }
    }
}
