//! The command struct file — the executable transfer of
//! `docs/architecture/blueprints/backend/domain/command.md`, ported from
//! `SpGen.Blueprint.Command` (`tools/spgen/lib/sp_gen/blueprint/command.ex`).
//!
//! Templates follow what the operation does:
//!
//! * `--template create` — the public API generates the id, so the command
//!   carries it enforced; required data fields enforce, optional ones stay free
//! * `--template update` — id enforced, data fields all partial
//! * `--template delete` — id only
//!
//! A command validates with the validators its invariants and constraints
//! imply: they are generated as this blueprint's dependencies, together with
//! the internal API they call and the lookup queries their accessors read
//! through (`SpGen.Blueprint.Validator`).
//!
//! Presence-based merging means running this over existing, hand-finished
//! commands is a no-op as long as module, `use`s, aliases, fields and
//! validations exist. A `validates` line counts as present only when it
//! carries every rule the model now states for that field; an incomplete
//! one is reported (`Outdated`) rather than appended to, because Vex keys
//! validations per field — a second line would replace the first, not
//! extend it.

use sparch_model::ElementKind;
use sparch_model::invariants::{Validator, ValidatorKind};

use crate::blueprints::validator::ValidatorBlueprint;
use crate::context::{Befield, Context};
use crate::elixir::{ElixirFile, Rank};
use crate::plan::{Blueprint, Dependency, FilePlan, Placement, Unit, UnitId};
use crate::templates;

const PATH: &str = "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/operations/<_operation>/command.ex";
const MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>";

pub struct Command;

impl Command {
    /// The command's module-name template (referenced by `CommandTest` and
    /// `CommandRouter`) — `Command.module_template/0`.
    pub fn module_template() -> &'static str {
        MODULE
    }

    /// The command module's file path (used as a `requires` gate) —
    /// `Command.module_file/1`.
    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(PATH)
    }
}

impl Blueprint for Command {
    fn name(&self) -> &'static str {
        "command"
    }

    fn description(&self) -> Option<&'static str> {
        Some("Generates a command module, its test and router registration")
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command]
    }

    fn is_fixed(&self) -> bool {
        false
    }

    /// `Command.operations` — create | update | delete | none.
    fn operations(&self) -> Vec<crate::context::Operation> {
        vec![
            crate::context::Operation::Create,
            crate::context::Operation::Update,
            crate::context::Operation::Delete,
            crate::context::Operation::None,
        ]
    }

    /// The operation is DECLARED in the model; `--template` may override —
    /// `Command.optional_template?`.
    fn optional_template(&self) -> bool {
        true
    }

    /// A command with rules generates the validators it validates with,
    /// from this very element — `Command.dependencies/1`.
    fn dependencies(&self, ctx: &Context) -> Vec<Dependency> {
        if ctx.validators.is_empty() {
            return Vec::new();
        }
        vec![Dependency {
            blueprint_name: "validator",
            element: ctx.element.clone(),
        }]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![
            (PATH, "typedstruct command with enforces"),
            (
                crate::blueprints::validator::PATH,
                "Vex rules per invariant",
            ),
        ]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        vec![FilePlan::new(
            ctx.render_or_panic(PATH),
            Some(ctx.render_or_panic(MODULE)),
            units(ctx),
        )]
    }
}

/// `Command.validator_module/2` — the validator's full module name as the
/// command references it through an alias.
fn validator_module(ctx: &Context, v: &Validator) -> String {
    ValidatorBlueprint::module_name(ctx, v)
}

// ------------------------------------------------------------------- units

fn units(ctx: &Context) -> Vec<Unit> {
    let mut units = vec![
        moduledoc_unit(ctx),
        use_unit("TypedStruct"),
        use_unit("ExConstructor"),
        use_unit("Vex.Struct"),
    ];
    units.extend(alias_units(ctx));
    units.extend(field_units(ctx));
    units.extend(validates_units(ctx));
    units
}

/// `Command.moduledoc_unit` — the prose slot filled from the model's
/// description (or its `TODO:` marker).
fn moduledoc_unit(ctx: &Context) -> Unit {
    let doc = ctx.render_or_panic(
        "<Describe what the command does to the aggregate, derived from the domain model.>",
    );
    Unit {
        id: UnitId::Moduledoc,
        check: Box::new(|f| f.has_moduledoc()),
        render: Box::new(move || format!("@moduledoc \"\"\"\n{doc}\n\"\"\"")),
        place: Placement::Head {
            rank: Rank::Moduledoc,
            alias_sort_key: None,
        },
        requires: Vec::new(),
        stale: None,
    }
}

fn use_unit(module: &str) -> Unit {
    let render = format!("use {module}");
    let check_module = module.to_string();
    Unit {
        id: UnitId::Use(module.to_string()),
        check: Box::new(move |f| f.has_use(&check_module)),
        render: Box::new(move || render.clone()),
        place: Placement::Head {
            rank: Rank::Use,
            alias_sort_key: None,
        },
        requires: Vec::new(),
        stale: None,
    }
}

fn alias_units(ctx: &Context) -> Vec<Unit> {
    // A rule naming several fields carries one descriptor per field and one
    // module for all of them: the alias is that module's, stated once.
    let mut seen: Vec<String> = Vec::new();
    ctx.validators
        .iter()
        .map(|v| {
            let full = validator_module(ctx, v);
            let check_module = full.clone();
            let render = format!("alias {full}");
            Unit {
                id: UnitId::Alias(full.clone()),
                check: Box::new(move |f| f.has_alias(&check_module)),
                render: Box::new(move || render.clone()),
                requires: validator_gate(ctx, v),
                place: Placement::Head {
                    rank: Rank::Alias,
                    alias_sort_key: Some(full.clone()),
                },
                stale: None,
            }
        })
        .filter(|u: &Unit| {
            let label = u.id.label();
            if seen.contains(&label) {
                false
            } else {
                seen.push(label);
                true
            }
        })
        .collect()
}

fn field_units(ctx: &Context) -> Vec<Unit> {
    ctx.fields
        .iter()
        .map(|f| {
            let key = format!(":{}", f.name);
            let render = templates::field_line(f);
            Unit {
                id: UnitId::Field(f.name.clone()),
                check: Box::new(move |file| file.has_entry("field", &key)),
                render: Box::new(move || render.clone()),
                place: Placement::Inside {
                    macro_name: "typedstruct".into(),
                    wrapper: Some("typedstruct do\n{unit}\nend".into()),
                    before_trailing: None,
                },
                requires: Vec::new(),
                stale: None,
            }
        })
        .collect()
}

/// The validator's own module file must exist before the command may name
/// it — `Command.validator_gate/2`.
fn validator_gate(ctx: &Context, v: &Validator) -> Vec<(String, String)> {
    vec![(
        ValidatorBlueprint::module_file(ctx, v),
        format!("validator {} not generated (sparch command)", v.snake),
    )]
}

fn validates_units(ctx: &Context) -> Vec<Unit> {
    ctx.fields
        .iter()
        .filter_map(|f| {
            let line = templates::validates_line(f, &ctx.validators)?;
            let render = exists_comment(f, &ctx.validators) + &line;
            let check_field = f.clone();
            let check_validators = ctx.validators.clone();
            let stale_field = check_field.clone();
            let stale_validators = check_validators.clone();
            let render = render.clone();
            Some(Unit {
                id: UnitId::Validates(f.name.clone()),
                check: Box::new(move |src: &ElixirFile| {
                    validates_complete(src, &check_field, &check_validators)
                }),
                render: Box::new(move || render.clone()),
                requires: validator_gates(ctx, f),
                place: Placement::AfterMacro {
                    macro_name: "validates".into(),
                    predicate: crate::plan::MacroPredicate::Any,
                    fallback: Box::new(Placement::AfterDirectives),
                },
                stale: Some(Box::new(move |src: &ElixirFile| {
                    stale_validations(src, &stale_field, &stale_validators)
                })),
            })
        })
        .collect()
}

/// every validator guarding the field gates the line: a `validates` line
/// may never reference a validator whose file does not exist —
/// `Command.validator_gates/2`.
fn validator_gates(ctx: &Context, field: &Befield) -> Vec<(String, String)> {
    templates::validators_for(field, &ctx.validators)
        .into_iter()
        .map(|v| {
            (
                ValidatorBlueprint::module_file(ctx, v),
                format!("validator {} not generated (sparch command)", v.snake),
            )
        })
        .collect()
}

// ------------------------------------------------------ validates currency

/// one `validates` line carries presence plus one `by:` pair per validator
/// (Vex keys validations by field, so a second call would replace the
/// first) — presence of *a* line is therefore not presence of *this* line.
/// A line is never appended twice: an incomplete one is reported instead.
/// — `Command.validates_complete?/3` (the Rust name drops the Elixir `?`).
fn validates_complete(src: &ElixirFile, field: &Befield, validators: &[Validator]) -> bool {
    line_present(src, field) && stale_validations(src, field, validators).is_empty()
}

fn stale_validations(src: &ElixirFile, field: &Befield, validators: &[Validator]) -> Vec<String> {
    if !line_present(src, field) {
        return Vec::new();
    }
    let key = format!(":{}", field.name);
    stale_details(&src.entry_kws("validates", &key), field, validators)
}

fn line_present(src: &ElixirFile, field: &Befield) -> bool {
    src.has_entry("validates", &format!(":{}", field.name))
}

fn stale_details(
    kws: &[(String, String)],
    field: &Befield,
    validators: &[Validator],
) -> Vec<String> {
    let by_values: Vec<&String> = kws
        .iter()
        .filter(|(key, _)| key == "by")
        .map(|(_, value)| value)
        .collect();

    let presence: Vec<String> = if templates::validates_presence(field)
        && !kws
            .iter()
            .any(|(key, value)| key == "presence" && value == "true")
    {
        vec!["add presence: true".to_string()]
    } else {
        Vec::new()
    };

    let missing: Vec<String> = templates::validators_for(field, validators)
        .into_iter()
        .filter(|v| {
            let needle = templates::validates_needle(v);
            !by_values.iter().any(|value| value.contains(&needle))
        })
        .map(|v| format!("add {}", templates::validates_by_pair(v, field)))
        .collect();

    presence.into_iter().chain(missing).collect()
}

/// The reference comment of the domain-object-exists example, said at the
/// line that carries the option: why `allow_blank` — and never a
/// `def validate(nil, _), do: :ok` clause (validator.md's contract).
/// — `Command.exists_comment/2`.
fn exists_comment(field: &Befield, validators: &[Validator]) -> String {
    let guards = templates::validators_for(field, validators);
    if guards.iter().any(|v| v.kind == ValidatorKind::Exists) {
        return format!(
            "# `allow_blank` keeps the existence check off an {} the caller never sent:\n# an absent address is `presence`'s to reject, and a `:not_found` for it would\n# turn the 422 the client can act on into a 404 for a resource nobody named.\n",
            field.name
        );
    }
    String::new()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
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

    fn units_for(name: &str) -> Vec<Unit> {
        Command.plans(&ctx_for(name)).remove(0).units
    }

    fn unit<'a>(units: &'a [Unit], label: &str) -> &'a Unit {
        units
            .iter()
            .find(|u| u.id.label() == label)
            .unwrap_or_else(|| panic!("no unit {label}"))
    }

    fn render(units: &[Unit], label: &str) -> String {
        (unit(units, label).render)()
    }

    #[test]
    fn paths_and_modules_render_like_the_oracle() {
        let ctx = ctx_for("create-widget");
        assert_eq!(
            Command::module_file(&ctx),
            "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/command.ex"
        );
        let plan = &Command.plans(&ctx)[0];
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget")
        );
        assert!(plan.unit_created);
    }

    #[test]
    fn unit_ids_and_order_mirror_the_oracle() {
        let units = units_for("create-widget");
        let labels: Vec<String> = units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            labels,
            vec![
                "moduledoc",
                "use TypedStruct",
                "use ExConstructor",
                "use Vex.Struct",
                "alias Sportipedia.Catalog.Equipment.Widget.Validators.AtMostOneOwner",
                "alias Sportipedia.Catalog.Equipment.Widget.Validators.UniqueSlug",
                "field id",
                "field title",
                "field slug",
                "field coachId",
                "field description",
                "field label",
                "field teamId",
                "validates title",
                "validates slug",
                "validates coachId",
                "validates teamId",
            ]
        );
    }

    #[test]
    fn a_rule_naming_two_fields_is_one_alias() {
        // at-most-one-owner carries a descriptor per field, the alias
        // stands once
        let units = units_for("create-widget");
        let aliases: Vec<String> = units
            .iter()
            .filter(|u| matches!(u.id, UnitId::Alias(_)))
            .map(|u| u.id.label())
            .collect();
        assert_eq!(aliases.len(), 2, "{aliases:?}");
    }

    #[test]
    fn the_validates_lines_carry_the_exact_oracle_text() {
        let units = units_for("create-widget");
        assert_eq!(
            render(&units, "validates title"),
            "validates :title, presence: true"
        );
        assert_eq!(
            render(&units, "validates slug"),
            "validates :slug, presence: true, by: [function: &UniqueSlug.validate/2, allow_nil: true]"
        );
        assert_eq!(
            render(&units, "validates coachId"),
            "validates :coachId, by: [function: &AtMostOneOwner.validate/2, allow_nil: true]"
        );
    }

    #[test]
    fn the_delete_line_says_allow_blank_over_the_by_id_lookup() {
        let units = units_for("archive-widget");
        assert_eq!(
            render(&units, "validates id"),
            "# `allow_blank` keeps the existence check off an id the caller never sent:\n# an absent address is `presence`'s to reject, and a `:not_found` for it would\n# turn the 422 the client can act on into a 404 for a resource nobody named.\nvalidates :id, presence: true, by: [function: &WidgetExists.validate/2, allow_blank: true]"
        );
    }

    #[test]
    fn the_create_id_carries_no_validates_line() {
        // create: the id is internal (the public API generates it) and no
        // rule guards it — parts empty, no line
        let units = units_for("create-widget");
        assert!(
            !units.iter().any(|u| u.id.label() == "validates id"),
            "the internal id is presence's silence"
        );
        // update/delete: the caller provides the id, `presence` speaks
        let updated = units_for("edit-widget");
        assert!(
            render(&updated, "validates id").contains("validates :id, presence: true"),
            "the provided id enforces presence"
        );
    }

    #[test]
    fn every_validates_line_waits_for_the_validators_it_names() {
        let ctx = ctx_for("edit-widget");
        let plan = &Command.plans(&ctx)[0];
        let slug = plan
            .units
            .iter()
            .find(|u| u.id.label() == "validates slug")
            .expect("the slug line");
        assert_eq!(
            slug.requires,
            vec![(
                "services/api/lib/sportipedia/catalog/equipment/widget/validators/unique_slug.ex"
                    .to_string(),
                "validator unique_slug not generated (sparch command)".to_string(),
            )]
        );
        // the id line names one validator: the exists check
        let id = plan
            .units
            .iter()
            .find(|u| u.id.label() == "validates id")
            .expect("the id line");
        assert_eq!(
            id.requires,
            vec![(
                "services/api/lib/sportipedia/catalog/equipment/widget/validators/widget_exists.ex"
                    .to_string(),
                "validator widget_exists not generated (sparch command)".to_string(),
            )]
        );
        // a rule descriptor pair: the coachId line gates on its own module
        let coach = plan
            .units
            .iter()
            .find(|u| u.id.label() == "validates coachId")
            .expect("the coachId line");
        assert_eq!(coach.requires.len(), 1);
        assert_eq!(
            coach.requires[0].1,
            "validator at_most_one_owner not generated (sparch command)"
        );
    }

    #[test]
    fn the_aliases_wait_for_the_validator_files() {
        let units = units_for("create-widget");
        let alias = unit(
            &units,
            "alias Sportipedia.Catalog.Equipment.Widget.Validators.UniqueSlug",
        );
        assert_eq!(
            alias.requires,
            vec![(
                "services/api/lib/sportipedia/catalog/equipment/widget/validators/unique_slug.ex"
                    .to_string(),
                "validator unique_slug not generated (sparch command)".to_string(),
            )]
        );
    }

    #[test]
    fn validators_arrive_as_the_dependency_of_their_command() {
        let deps = Command.dependencies(&ctx_for("create-widget"));
        assert_eq!(deps.len(), 1);
        assert_eq!(deps[0].blueprint_name, "validator");
        assert_eq!(deps[0].element.name, "create-widget");
        // a citizen no rule guards generates no validator — the corpus
        // commands all carry rules, so the empty branch is driven from a
        // context with the resolved rules cleared
        let mut bare = ctx_for("create-widget");
        bare.validators.clear();
        assert!(Command.dependencies(&bare).is_empty());
    }

    #[test]
    fn an_incomplete_line_reports_the_missing_parts_and_never_appends() {
        // the currency check over a hand-shortened file: presence of a line
        // is not presence of THIS line
        let text = "defmodule M do\n  validates :slug, presence: true\nend\n";
        let file = ElixirFile::parse(text);
        let ctx = ctx_for("create-widget");
        let slug = ctx.fields.iter().find(|f| f.name == "slug").expect("slug");
        assert!(!validates_complete(&file, slug, &ctx.validators));
        assert_eq!(
            stale_validations(&file, slug, &ctx.validators),
            vec!["add by: [function: &UniqueSlug.validate/2, allow_nil: true]".to_string()]
        );
        // the same line without the presence part asks for both
        let text = "defmodule M do\n  validates :slug, by: [function: &UniqueSlug.validate/2, allow_nil: true]\nend\n";
        let file = ElixirFile::parse(text);
        assert_eq!(
            stale_validations(&file, slug, &ctx.validators),
            vec!["add presence: true".to_string()]
        );
        // the complete line is complete
        let text = "defmodule M do\n  validates :slug, presence: true, by: [function: &UniqueSlug.validate/2, allow_nil: true]\nend\n";
        let file = ElixirFile::parse(text);
        assert!(validates_complete(&file, slug, &ctx.validators));
        // no line at all is missing, not stale: the unit renders fresh
        let text = "defmodule M do\n  field :slug, String.t()\nend\n";
        let file = ElixirFile::parse(text);
        assert!(stale_validations(&file, slug, &ctx.validators).is_empty());
    }

    #[test]
    fn the_finished_command_file_is_fully_present() {
        // what the oracle creates, parsed back: every unit reads present
        let text = "defmodule Sportipedia.Catalog.Equipment.Widget.Command.ArchiveWidget do\n  @moduledoc \"\"\"\n  Archives a widget that is no longer used\n  \"\"\"\n  use TypedStruct\n  use ExConstructor\n  use Vex.Struct\n  alias Sportipedia.Catalog.Equipment.Widget.Validators.WidgetExists\n\n  # `allow_blank` keeps the existence check off an id the caller never sent:\n  # an absent address is `presence`'s to reject, and a `:not_found` for it would\n  # turn the 422 the client can act on into a 404 for a resource nobody named.\n  validates :id, presence: true, by: [function: &WidgetExists.validate/2, allow_blank: true]\n\n  typedstruct do\n    field :id, String.t(), enforce: true\n  end\nend\n";
        let file = ElixirFile::parse(text);
        for unit in &units_for("archive-widget") {
            assert!((unit.check)(&file), "{} must read present", unit.id.label());
        }
    }

    #[test]
    fn the_validates_lines_land_below_the_directives_above_the_struct() {
        let units = units_for("archive-widget");
        let place = &unit(&units, "validates id").place;
        assert!(matches!(
            place,
            Placement::AfterMacro { macro_name, .. } if macro_name == "validates"
        ));
        // with no `validates` entry to follow, the fallback is the start of
        // the code region — below the aliases it references
        let shell = ElixirFile::parse(
            "defmodule M do\n  alias Sportipedia.Catalog.Equipment.Widget.Validators.WidgetExists\n\n  typedstruct do\n    field :id, String.t(), enforce: true\n  end\nend\n",
        );
        let (offset, _) = place
            .locate(&shell, "validates :id, presence: true")
            .unwrap();
        let next = shell.splice(offset, "validates :id, presence: true\n");
        assert!(
            next.contains("validates :id, presence: true\n  typedstruct do"),
            "the line lands above the typedstruct block:\n{next}"
        );
        // and a second line joins after the first
        let (offset, _) = unit(&units, "validates id")
            .place
            .locate(
                &ElixirFile::parse(&next),
                "validates :second, presence: true",
            )
            .unwrap();
        let grown = ElixirFile::parse(&next).splice(offset, "validates :second, presence: true\n");
        assert!(
            grown.contains("validates :id, presence: true\nvalidates :second, presence: true"),
            "the validates cluster stays grouped:\n{grown}"
        );
    }
}
