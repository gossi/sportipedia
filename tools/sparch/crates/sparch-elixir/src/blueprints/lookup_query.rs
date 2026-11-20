//! The lookup query behind a unique-field accessor — ported from
//! `SpGen.Blueprint.LookupQuery`
//! (`tools/spgen/lib/sp_gen/blueprint/lookup_query.ex`), the executable
//! transfer of the query half of
//! `docs/architecture/blueprints/backend/domain/examples/unique-slug.md`.
//!
//! One `Queries.<DomainObject>By<Field>` module per field a unique invariant
//! declares: the single-value lookup the internal API accessor delegates to.
//! It is not an ESDM `query` element — the model states the invariant, not
//! the read side of it — so this blueprint derives the shape from the pattern
//! while [`crate::blueprints::query`] transfers the citizen's modelled
//! queries.
//!
//! Not a generator. `SpGen.generators/0` holds no `lookup_query` entry: the
//! [internal API](crate::blueprints) reaches it through `dependencies/1`, so
//! the accessor and its query appear together in one run and no generated
//! code ever calls a module that is not there. That is why this module joins
//! [`crate::blueprints::by_name`] (the dependency lookup) and not the
//! registry, nor [`crate::blueprints::all`] — the oracle's closure sweep
//! builds its groups from the registry's module lists, so this blueprint
//! reaches the sweep only inside its caller's group, from the element that
//! caller passes.

use sparch_model::ElementKind;
use sparch_model::placeholders::Vars;

use crate::blueprints::read_model::ReadModel;
use crate::context::Context;
use crate::elixir::{ElixirFile, Rank};
use crate::plan::{Blueprint, Dependency, FilePlan, Placement, Unit, UnitId};

pub(crate) const PATH: &str =
    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/queries/<_query>.ex";
const MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<Query>";
const READ_MODEL_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel";

pub struct LookupQuery;

impl LookupQuery {
    /// The query name of a unique field (`position-by-slug`) —
    /// `LookupQuery.query_name/2`.
    pub fn query_name(ctx: &Context, field: &str) -> String {
        format!("{}-by-{field}", ctx.constituent)
    }

    /// The lookup query's module name for `field` (used to alias it) —
    /// `LookupQuery.module_name/2`.
    pub fn module_name(ctx: &Context, field: &str) -> String {
        ctx.render_or_panic_with(MODULE, &query_vars(ctx, field))
    }

    /// The lookup query's module name as code refers to it
    /// (`PositionBySlug`) — `LookupQuery.short_name/2`.
    pub fn short_name(ctx: &Context, field: &str) -> String {
        let module = Self::module_name(ctx, field);
        module.rsplit('.').next().unwrap_or(&module).to_string()
    }

    /// The lookup query's file path (used as a `requires` gate) —
    /// `LookupQuery.module_file/2`.
    pub fn module_file(ctx: &Context, field: &str) -> String {
        ctx.render_or_panic_with(PATH, &query_vars(ctx, field))
    }
}

/// The `<query>` placeholder override this blueprint drives every template
/// with — the Elixir `%{"query" => query_name(ctx, field)}`.
fn query_vars(ctx: &Context, field: &str) -> Vars {
    let mut vars = Vars::new();
    vars.insert("query".to_string(), LookupQuery::query_name(ctx, field));
    vars
}

impl Blueprint for LookupQuery {
    fn name(&self) -> &'static str {
        "lookup_query"
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![
            ElementKind::ReadModel,
            ElementKind::Aggregate,
            ElementKind::Command,
        ]
    }

    /// Every lookup query reads its constituent's read model —
    /// `LookupQuery.dependencies/1`.
    fn dependencies(&self, ctx: &Context) -> Vec<Dependency> {
        ctx.read_model
            .as_ref()
            .map(|element| {
                vec![Dependency {
                    blueprint_name: "read_model",
                    element: element.clone(),
                }]
            })
            .unwrap_or_default()
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(PATH, "read model lookup by field")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        ctx.unique_fields()
            .into_iter()
            .map(|field| {
                FilePlan::new(
                    Self::module_file(ctx, &field),
                    Some(Self::module_name(ctx, &field)),
                    units(ctx, &field),
                )
            })
            .collect()
    }
}

/// The read model as the `from` names it, through its alias —
/// `LookupQuery.read_model/1`.
fn read_model(ctx: &Context) -> String {
    format!("{}ReadModel", Context::pascal(&ctx.constituent))
}

/// `LookupQuery.def_block/2` — the one clause that is complete on generation:
/// the field is unique, so the query is the model's own statement.
fn def_block(ctx: &Context, field: &str) -> String {
    format!(
        "@doc \"\"\"\nCreates a new query to fetch a {} by {field}.\n\"\"\"\n@spec new(String.t()) :: Ecto.Query.t()\ndef new({field}) do\n  from(r in {},\n    where: r.{field} == ^{field}\n  )\nend",
        ctx.constituent,
        read_model(ctx)
    )
}

// ------------------------------------------------------------------- units

fn units(ctx: &Context, field: &str) -> Vec<Unit> {
    let read_model_module = ctx.render_or_panic(READ_MODEL_MODULE);
    // plans are per-context: every render resolves now, the way
    // `FilePlan` documents the Elixir closures' context dependency
    let moduledoc_text = format!(
        "@moduledoc \"\"\"\nQuery to fetch a {} by its {field}.\n\"\"\"",
        ctx.constituent
    );
    let alias_text = format!("alias {read_model_module}");
    let clause_text = def_block(ctx, field);
    let gate = read_model_gate(ctx);

    vec![
        Unit {
            id: UnitId::Moduledoc,
            check: Box::new(|f| f.has_moduledoc()),
            render: Box::new(move || moduledoc_text.clone()),
            place: Placement::Head {
                rank: Rank::Moduledoc,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        },
        Unit {
            id: UnitId::Alias(read_model_module.clone()),
            check: Box::new({
                let module = read_model_module.clone();
                move |f: &ElixirFile| f.has_alias(&module)
            }),
            render: Box::new(move || alias_text.clone()),
            requires: gate.clone(),
            place: Placement::Head {
                rank: Rank::Alias,
                alias_sort_key: Some(read_model_module),
            },
            stale: None,
        },
        Unit {
            id: UnitId::Import("Ecto.Query".into()),
            check: Box::new(|f| f.has_import("Ecto.Query")),
            render: Box::new(|| "import Ecto.Query".to_string()),
            place: Placement::Head {
                rank: Rank::Import,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        },
        Unit {
            id: UnitId::Def("new".to_string(), 1),
            check: Box::new(|f| f.has_def("new", 1)),
            render: Box::new(move || clause_text.clone()),
            requires: gate,
            place: Placement::BodyEnd,
            stale: None,
        },
    ]
}

/// The read model must exist before the query may name it —
/// `LookupQuery.read_model_gate/0`.
fn read_model_gate(ctx: &Context) -> Vec<(String, String)> {
    vec![(
        ReadModel::module_file(ctx),
        "read model not generated (sparch read_model)".to_string(),
    )]
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
            .resolve(name, &[ElementKind::ReadModel])
            .expect("fixture read model");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn labels(units: &[Unit]) -> Vec<String> {
        units.iter().map(|u| u.id.label()).collect()
    }

    fn render(units: &[Unit], label: &str) -> String {
        let unit = units
            .iter()
            .find(|u| u.id.label() == label)
            .unwrap_or_else(|| panic!("no unit {label}"));
        (unit.render)()
    }

    #[test]
    fn one_plan_per_unique_field_of_the_citizen() {
        let ctx = ctx_for("widget");
        assert_eq!(ctx.unique_fields(), vec!["slug".to_string()]);
        let plans = LookupQuery.plans(&ctx);
        assert_eq!(plans.len(), 1);
        assert_eq!(
            plans[0].path,
            "services/api/lib/sportipedia/catalog/equipment/widget/queries/widget_by_slug.ex"
        );
        assert_eq!(
            plans[0].module.as_deref(),
            Some("Sportipedia.Catalog.Equipment.Widget.Queries.WidgetBySlug")
        );
        assert!(plans[0].unit_created);
    }

    #[test]
    fn the_names_read_from_every_angle_the_caller_needs() {
        let ctx = ctx_for("apparatus");
        assert_eq!(
            LookupQuery::query_name(&ctx, "slug"),
            "apparatus-by-slug".to_string()
        );
        assert_eq!(
            LookupQuery::module_name(&ctx, "slug"),
            "Sportipedia.Catalog.Equipment.Apparatus.Queries.ApparatusBySlug"
        );
        assert_eq!(LookupQuery::short_name(&ctx, "slug"), "ApparatusBySlug");
        assert_eq!(
            LookupQuery::module_file(&ctx, "slug"),
            "services/api/lib/sportipedia/catalog/equipment/apparatus/queries/apparatus_by_slug.ex"
        );
    }

    #[test]
    fn the_units_are_moduledoc_alias_import_then_the_clause() {
        let ctx = ctx_for("widget");
        let plan = LookupQuery.plans(&ctx).remove(0);
        assert_eq!(
            labels(&plan.units),
            vec![
                "moduledoc",
                "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel",
                "import Ecto.Query",
                "new/1",
            ]
        );
        // the `import` ranks above the `alias` in the directive block, so the
        // file reads import first even though the alias unit comes earlier
        let Placement::Head {
            rank: Rank::Alias,
            alias_sort_key: Some(key),
        } = &plan.units[1].place
        else {
            panic!("the alias lands in the alias block");
        };
        assert_eq!(key, "Sportipedia.Catalog.Equipment.Widget.WidgetReadModel");
        assert!(matches!(
            plan.units[2].place,
            Placement::Head {
                rank: Rank::Import,
                ..
            }
        ));
    }

    #[test]
    fn the_body_is_complete_on_generation() {
        let ctx = ctx_for("widget");
        let plan = LookupQuery.plans(&ctx).remove(0);
        assert_eq!(
            render(&plan.units, "moduledoc"),
            "@moduledoc \"\"\"\nQuery to fetch a widget by its slug.\n\"\"\""
        );
        assert_eq!(
            render(&plan.units, "new/1"),
            "@doc \"\"\"\nCreates a new query to fetch a widget by slug.\n\"\"\"\n@spec new(String.t()) :: Ecto.Query.t()\ndef new(slug) do\n  from(r in WidgetReadModel,\n    where: r.slug == ^slug\n  )\nend"
        );
    }

    #[test]
    fn the_alias_and_the_clause_wait_for_the_read_model() {
        let ctx = ctx_for("widget");
        let plan = LookupQuery.plans(&ctx).remove(0);
        let gate = vec![(
            "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex".to_string(),
            "read model not generated (sparch read_model)".to_string(),
        )];
        assert_eq!(plan.units[1].requires, gate);
        assert_eq!(plan.units[3].requires, gate);
        assert!(plan.units[0].requires.is_empty());
        assert!(plan.units[2].requires.is_empty());
    }

    #[test]
    fn the_read_model_is_a_planned_dependency() {
        let deps = LookupQuery.dependencies(&ctx_for("widget"));
        assert_eq!(deps.len(), 1);
        assert_eq!(deps[0].blueprint_name, "read_model");
        assert_eq!(deps[0].element.name, "widget");
    }

    #[test]
    fn a_present_clause_is_present() {
        let ctx = ctx_for("widget");
        let plan = LookupQuery.plans(&ctx).remove(0);
        let file = ElixirFile::parse(
            "defmodule M do\n  import Ecto.Query\n  alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel\n\n  def new(slug) do\n    from(r in WidgetReadModel, where: r.slug == ^slug)\n  end\nend\n",
        );
        assert!((plan.units[1].check)(&file));
        assert!((plan.units[2].check)(&file));
        assert!((plan.units[3].check)(&file));
        assert!(!(plan.units[0].check)(&file), "no moduledoc there");
    }

    #[test]
    fn a_citizen_with_no_unique_field_gets_no_lookup_query() {
        // the exercise read model states no unique invariant (and its
        // projection names no aggregate that does), so there is nothing a
        // `By<Field>` query could look up
        let ctx = ctx_for("exercise");
        assert!(ctx.unique_fields().is_empty());
        assert!(LookupQuery.plans(&ctx).is_empty());
    }
}
