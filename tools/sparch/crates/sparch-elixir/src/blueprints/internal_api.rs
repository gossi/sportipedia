//! The constituent's internal API — the executable transfer of
//! `docs/architecture/blueprints/backend/domain/internal-api.md`, ported from
//! `SpGen.Blueprint.InternalAPI`
//! (`tools/spgen/lib/sp_gen/blueprint/internal_api.ex`).
//!
//! `x_by_id/1` through `Repo`, plus one accessor per unique-field invariant
//! (`x_by_slug/1`, lowercasing the value and delegating to the lookup query
//! from the `unique-slug` example). Used within the constituent only: a
//! lookup another constituent needs goes through the public API, not here.
//!
//! It is reached two ways — as its own generator, and (from the command wave
//! on) as the dependency of every validator a command generates. Its
//! `dependencies` plan the read model it reads and the lookup query its
//! accessor delegates to, so a generated accessor never points at a module
//! that does not exist.
//!
//! Unit order note: the oracle checks every unit's presence against the file
//! snapshot it read at entry, then threads the *placements* through the AST.
//! The ported engine's checks read the file as earlier units of the same plan
//! have left it, and the oracle's alias check counts a unit present when its
//! owner accessor is defined (`alias_unit`'s `has_alias || has_def` fallback
//! — the pickup contract for a hand-written accessor without its alias).
//! Listing an accessor before its aliases would therefore drop the aliases
//! when a fresh file is created. Each accessor here comes after its own
//! aliases; the directive block and the code region are placed independently
//! (`Merge.alias_of` sorts, `Merge.before_helpers` keeps public defs above
//! the `defp`s), so the landed file is the oracle's byte for byte.

use sparch_model::ElementKind;

use crate::blueprints::lookup_query::LookupQuery;
use crate::blueprints::read_model::ReadModel;
use crate::context::Context;
use crate::elixir::Rank;
use crate::plan::{Blueprint, Dependency, FilePlan, Placement, Unit, UnitId};

const PATH: &str =
    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/internal.ex";
const MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal";
const READ_MODEL_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel";
const REPO_MODULE: &str = "Sportipedia.<Subdomain>.Repo";

pub struct InternalApi;

impl InternalApi {
    /// The internal API's file path (used as a `requires` gate) —
    /// `InternalAPI.module_file/1`.
    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(PATH)
    }
}

impl Blueprint for InternalApi {
    fn name(&self) -> &'static str {
        "internal_api"
    }

    fn description(&self) -> Option<&'static str> {
        Some("Generates the internal API accessors for a constituent")
    }

    /// `InternalAPI.source_kinds` — the internal API belongs to the citizen,
    /// not to one of its operations: any element of the constituent drives
    /// the same file. A bare name naming both the aggregate and the read
    /// model stays ambiguous; `kind.name` addresses it.
    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![
            ElementKind::ReadModel,
            ElementKind::Aggregate,
            ElementKind::Command,
            ElementKind::Event,
            ElementKind::Query,
        ]
    }

    /// The read model the by_id lookup reads, and — when the citizen states a
    /// unique-field invariant — the lookup query the accessor delegates to.
    /// Both planned from the read model element itself, not the
    /// partially-shaped element the run was addressed by —
    /// `InternalAPI.dependencies/1`.
    fn dependencies(&self, ctx: &Context) -> Vec<Dependency> {
        let Some(element) = ctx.read_model.as_ref() else {
            return Vec::new();
        };
        let mut deps = vec![Dependency {
            blueprint_name: "read_model",
            element: element.clone(),
        }];
        if !ctx.unique_fields().is_empty() {
            deps.push(Dependency {
                blueprint_name: "lookup_query",
                element: element.clone(),
            });
        }
        deps
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![
            (PATH, "by-id and unique accessors"),
            (
                crate::blueprints::lookup_query::PATH,
                "lookup behind unique accessor",
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

// ------------------------------------------------------------------ clauses

/// The read model as the clauses name it, through its alias —
/// `Context.pascal(ctx.constituent) <> "ReadModel"` inside `by_id_clause/1`.
fn read_model_local(ctx: &Context) -> String {
    format!("{}ReadModel", Context::pascal(&ctx.constituent))
}

/// `InternalAPI.by_id_clause/1` — the `Repo.get` over the read model.
fn by_id_clause(ctx: &Context, name: &str) -> String {
    let read_model = read_model_local(ctx);
    format!(
        "@doc \"\"\"\nFetches a {} by its ID. Returns nil if not found.\n\"\"\"\n@spec {name}(String.t()) :: {read_model}.t() | nil\ndef {name}(id) do\n  Repo.get({read_model}, id)\nend",
        ctx.constituent
    )
}

/// `InternalAPI.accessor_clause/2` — the lowercasing delegation to the
/// lookup query.
fn accessor_clause(ctx: &Context, name: &str, field: &str) -> String {
    let read_model = read_model_local(ctx);
    let query = LookupQuery::short_name(ctx, field);
    format!(
        "@doc \"\"\"\nFetches a {} by its {field}. Returns nil if not found.\n\"\"\"\n@spec {name}(String.t()) :: {read_model}.t() | nil\ndef {name}({field}) do\n  {field}\n  |> String.downcase()\n  |> {query}.new()\n  |> Repo.one()\nend",
        ctx.constituent
    )
}

// ------------------------------------------------------------------- units

fn units(ctx: &Context) -> Vec<Unit> {
    let do_ = &ctx.constituent;
    let by_id = format!("{do_}_by_id");
    let rm_gate = read_model_gate(ctx);

    let mut units = vec![
        // the module is a lookup surface: without its read model nothing is
        // placeable, so the file appears with the first accessor it can hold
        moduledoc_unit(ctx, rm_gate.clone()),
        alias_unit(
            ctx.render_or_panic(READ_MODEL_MODULE),
            &by_id,
            rm_gate.clone(),
        ),
        // the Repo is shared support, never a citizen a run creates
        alias_unit(ctx.render_or_panic(REPO_MODULE), &by_id, Vec::new()),
        def_unit(by_id.clone(), by_id_clause(ctx, &by_id), rm_gate),
    ];

    for field in ctx.unique_fields() {
        let accessor = format!("{do_}_by_{field}");
        let gate = query_gate(ctx, &field);
        units.push(alias_unit(
            LookupQuery::module_name(ctx, &field),
            &accessor,
            gate.clone(),
        ));
        units.push(def_unit(
            accessor.clone(),
            accessor_clause(ctx, &accessor, &field),
            gate,
        ));
    }

    units
}

fn moduledoc_unit(ctx: &Context, requires: Vec<(String, String)>) -> Unit {
    let render = format!(
        "@moduledoc \"\"\"\nInternal API for querying {} read models within the bounded context.\n\"\"\"",
        ctx.constituent
    );
    Unit {
        id: UnitId::Moduledoc,
        check: Box::new(|f| f.has_moduledoc()),
        render: Box::new(move || render.clone()),
        requires,
        place: Placement::Head {
            rank: Rank::Moduledoc,
            alias_sort_key: None,
        },
        stale: None,
    }
}

/// `InternalAPI.alias_unit/3` — the alias a clause needs to compile. It
/// counts as present when the alias line stands *or* when the accessor that
/// uses it is defined: whoever wrote the accessor by hand owns the alias too.
fn alias_unit(module: String, owner_def: &str, requires: Vec<(String, String)>) -> Unit {
    let check_module = module.clone();
    let check_def = owner_def.to_string();
    let render = format!("alias {module}");
    Unit {
        id: UnitId::Alias(module.clone()),
        check: Box::new(move |f| f.has_alias(&check_module) || f.has_def(&check_def, 1)),
        render: Box::new(move || render.clone()),
        requires,
        place: Placement::Head {
            rank: Rank::Alias,
            alias_sort_key: Some(module),
        },
        stale: None,
    }
}

/// One accessor clause — the oracle's `%Unit{id: {:def, name, 1}}` with
/// `check: &Source.has_def?/3` and `place: Merge.before_helpers()`. The
/// clause text resolves at plan time, like every other BE blueprint here.
fn def_unit(name: String, clause: String, requires: Vec<(String, String)>) -> Unit {
    let def_name = name.clone();
    Unit {
        id: UnitId::Def(name, 1),
        check: Box::new(move |f| f.has_def(&def_name, 1)),
        render: Box::new(move || clause.clone()),
        requires,
        place: Placement::BeforeHelpers,
        stale: None,
    }
}

/// The read model must be generated before the module may name it —
/// `InternalAPI.read_model_gate/0`.
fn read_model_gate(ctx: &Context) -> Vec<(String, String)> {
    vec![(
        ReadModel::module_file(ctx),
        "read model not generated (sparch read_model)".to_string(),
    )]
}

/// The accessor delegates to the lookup query module; it is only placeable
/// once that module exists (the dependency pass creates it in this same run)
/// — `InternalAPI.query_gate/1`.
fn query_gate(ctx: &Context, field: &str) -> Vec<(String, String)> {
    vec![(
        LookupQuery::module_file(ctx, field),
        format!("lookup query for {field} not generated (sparch internal_api)"),
    )]
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use crate::elixir::ElixirFile;
    use sparch_model::Model;
    use std::path::PathBuf;

    fn ctx_for(name: &str, kind: ElementKind) -> Context {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model.resolve(name, &[kind]).expect("fixture element");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn widget_ctx() -> Context {
        ctx_for("widget", ElementKind::Aggregate)
    }

    fn units_for(name: &str, kind: ElementKind) -> Vec<Unit> {
        InternalApi.plans(&ctx_for(name, kind)).remove(0).units
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
        let ctx = widget_ctx();
        assert_eq!(
            InternalApi::module_file(&ctx),
            "services/api/lib/sportipedia/catalog/equipment/widget/internal.ex"
        );
        let plan = &InternalApi.plans(&ctx)[0];
        assert_eq!(
            plan.path,
            "services/api/lib/sportipedia/catalog/equipment/widget/internal.ex"
        );
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.Catalog.Equipment.Widget.WidgetInternal")
        );
        assert!(plan.unit_created);
        assert!(plan.format);
        assert!(!plan.requires_describe);
    }

    #[test]
    fn the_units_are_moduledoc_aliases_by_id_then_the_accessor_pair() {
        let units = units_for("widget", ElementKind::Aggregate);
        let labels: Vec<String> = units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            labels,
            vec![
                "moduledoc",
                "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel",
                "alias Sportipedia.Catalog.Repo",
                "widget_by_id/1",
                "alias Sportipedia.Catalog.Equipment.Widget.Queries.WidgetBySlug",
                "widget_by_slug/1",
            ]
        );
    }

    #[test]
    fn the_clauses_carry_the_exact_oracle_text() {
        let units = units_for("widget", ElementKind::Aggregate);
        assert_eq!(
            render(&units, "moduledoc"),
            "@moduledoc \"\"\"\nInternal API for querying widget read models within the bounded context.\n\"\"\""
        );
        assert_eq!(
            render(&units, "widget_by_id/1"),
            "@doc \"\"\"\nFetches a widget by its ID. Returns nil if not found.\n\"\"\"\n@spec widget_by_id(String.t()) :: WidgetReadModel.t() | nil\ndef widget_by_id(id) do\n  Repo.get(WidgetReadModel, id)\nend"
        );
        assert_eq!(
            render(&units, "widget_by_slug/1"),
            "@doc \"\"\"\nFetches a widget by its slug. Returns nil if not found.\n\"\"\"\n@spec widget_by_slug(String.t()) :: WidgetReadModel.t() | nil\ndef widget_by_slug(slug) do\n  slug\n  |> String.downcase()\n  |> WidgetBySlug.new()\n  |> Repo.one()\nend"
        );
        assert_eq!(
            render(
                &units,
                "alias Sportipedia.Catalog.Equipment.Widget.Queries.WidgetBySlug"
            ),
            "alias Sportipedia.Catalog.Equipment.Widget.Queries.WidgetBySlug"
        );
    }

    #[test]
    fn every_lookup_surface_unit_waits_for_its_citizen() {
        let units = units_for("widget", ElementKind::Aggregate);
        let rm_gate = vec![(
            "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex".to_string(),
            "read model not generated (sparch read_model)".to_string(),
        )];
        assert_eq!(unit(&units, "moduledoc").requires, rm_gate);
        assert_eq!(unit(&units, "widget_by_id/1").requires, rm_gate);
        assert_eq!(
            unit(
                &units,
                "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel"
            )
            .requires,
            rm_gate
        );
        // the Repo is shared support, never a citizen a run creates
        assert!(
            unit(&units, "alias Sportipedia.Catalog.Repo")
                .requires
                .is_empty()
        );
        // the accessor pair waits for the lookup query behind it
        let lookup_gate = vec![(
            "services/api/lib/sportipedia/catalog/equipment/widget/queries/widget_by_slug.ex"
                .to_string(),
            "lookup query for slug not generated (sparch internal_api)".to_string(),
        )];
        assert_eq!(unit(&units, "widget_by_slug/1").requires, lookup_gate);
        assert_eq!(
            unit(
                &units,
                "alias Sportipedia.Catalog.Equipment.Widget.Queries.WidgetBySlug"
            )
            .requires,
            lookup_gate
        );
    }

    #[test]
    fn the_read_model_and_lookup_query_are_dependencies() {
        let deps = InternalApi.dependencies(&widget_ctx());
        assert_eq!(deps.len(), 2, "read model first, then the lookup query");
        assert_eq!(deps[0].blueprint_name, "read_model");
        assert_eq!(deps[0].element.name, "widget");
        assert_eq!(deps[0].element.kind, ElementKind::ReadModel);
        assert_eq!(deps[1].blueprint_name, "lookup_query");
        assert_eq!(deps[1].element.name, "widget");
    }

    #[test]
    fn a_citizen_without_unique_fields_pulls_no_lookup_query() {
        // the apparatus states `unique-equipment-slug` — a field name the
        // pattern does not carry — so no `By<Field>` accessor exists
        let ctx = ctx_for("apparatus", ElementKind::Aggregate);
        assert!(ctx.unique_fields().is_empty());
        let deps = InternalApi.dependencies(&ctx);
        assert_eq!(deps.len(), 1);
        assert_eq!(deps[0].blueprint_name, "read_model");
        let units = units_for("apparatus", ElementKind::Aggregate);
        let labels: Vec<String> = units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            labels,
            vec![
                "moduledoc",
                "alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel",
                "alias Sportipedia.Catalog.Repo",
                "apparatus_by_id/1",
            ]
        );
        assert!(render(&units, "apparatus_by_id/1").contains("Repo.get(ApparatusReadModel, id)"));
        assert!(
            render(&units, "moduledoc").contains("Internal API for querying apparatus read models")
        );
    }

    #[test]
    fn the_aliases_fall_back_to_their_owning_accessor() {
        // pickup: a hand-written accessor without its alias line is complete
        // code — the alias unit counts it, and the tool never pushes into it
        let text = "defmodule M do\n  def widget_by_id(id) do\n    Repo.get(WidgetReadModel, id)\n  end\n\n  def widget_by_slug(slug) do\n    slug |> WidgetBySlug.new() |> Repo.one()\n  end\nend\n";
        let file = ElixirFile::parse(text);
        let units = units_for("widget", ElementKind::Aggregate);
        assert!((unit(
            &units,
            "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel"
        )
        .check)(&file));
        assert!((unit(&units, "alias Sportipedia.Catalog.Repo").check)(
            &file
        ));
        assert!((unit(
            &units,
            "alias Sportipedia.Catalog.Equipment.Widget.Queries.WidgetBySlug"
        )
        .check)(&file));
        assert!((unit(&units, "widget_by_id/1").check)(&file));
        assert!((unit(&units, "widget_by_slug/1").check)(&file));
        // the moduledoc is not carried by the defs: it really is missing
        assert!(!(unit(&units, "moduledoc").check)(&file));
    }

    #[test]
    fn an_empty_shell_holds_nothing() {
        let file = ElixirFile::parse(
            "defmodule Sportipedia.Catalog.Equipment.Widget.WidgetInternal do\nend\n",
        );
        let units = units_for("widget", ElementKind::Aggregate);
        for unit in &units {
            assert!(
                !(unit.check)(&file),
                "{} must be missing from the shell",
                unit.id.label()
            );
        }
    }

    #[test]
    fn the_finished_module_is_fully_present() {
        // the file the oracle creates, parsed back: every unit reads present
        let text = "defmodule Sportipedia.Catalog.Equipment.Widget.WidgetInternal do\n  @moduledoc \"\"\"\n  Internal API for querying widget read models within the bounded context.\n  \"\"\"\n  alias Sportipedia.Catalog.Equipment.Widget.Queries.WidgetBySlug\n  alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel\n  alias Sportipedia.Catalog.Repo\n\n  def widget_by_id(id) do\n    Repo.get(WidgetReadModel, id)\n  end\n\n  def widget_by_slug(slug) do\n    slug\n    |> String.downcase()\n    |> WidgetBySlug.new()\n    |> Repo.one()\n  end\nend\n";
        let file = ElixirFile::parse(text);
        let units = units_for("widget", ElementKind::Aggregate);
        for unit in &units {
            assert!((unit.check)(&file), "{} must read present", unit.id.label());
        }
    }

    #[test]
    fn the_defs_land_before_the_helpers_and_the_aliases_sort() {
        let units = units_for("widget", ElementKind::Aggregate);
        assert!(matches!(
            unit(&units, "widget_by_id/1").place,
            Placement::BeforeHelpers
        ));
        assert!(matches!(
            unit(&units, "widget_by_slug/1").place,
            Placement::BeforeHelpers
        ));
        let Placement::Head {
            rank: Rank::Alias,
            alias_sort_key: Some(key),
        } = &unit(&units, "alias Sportipedia.Catalog.Repo").place
        else {
            panic!("the repo alias joins the sorted alias block");
        };
        assert_eq!(key, "Sportipedia.Catalog.Repo");
    }

    #[test]
    fn any_element_of_the_citizen_drives_the_same_file() {
        // source_kinds: [read-model, aggregate, command, event, query] —
        // the oracle addresses the internal API from each of them; the
        // widget command `create-widget` drives the same plan
        let ctx = ctx_for("create-widget", ElementKind::Command);
        let plan = &InternalApi.plans(&ctx)[0];
        assert_eq!(
            plan.path,
            "services/api/lib/sportipedia/catalog/equipment/widget/internal.ex"
        );
        assert!(
            plan.units
                .iter()
                .any(|u| u.id.label() == "widget_by_slug/1")
        );
    }
}
