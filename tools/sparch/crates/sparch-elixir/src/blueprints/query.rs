//! The query module file — the executable transfer of
//! `docs/architecture/blueprints/backend/domain/query.md`, ported from
//! `SpGen.Blueprint.Query` (`tools/spgen/lib/sp_gen/blueprint/query.ex`).
//!
//! One `new/1` constructor over the constituent's read model. What its body
//! is depends on what the model declares the query to be:
//!
//! * a `collection` read — its parameters *are* the standard JSON:API set
//!   (`filter`/`sort`/`page`/`fields`), so nothing in the model is left
//!   unimplemented and the blueprint ships the working body: delegate to the
//!   shared `Sportipedia.Support.JSONAPI.QueryBuilder` over the read model,
//!   with the two aliases that body names
//! * anything else — the Ecto query depends on the feature specification (the
//!   last 1% the blueprint leaves to the spec), so the body carries a stable
//!   `TODO:` marker that raises
//!
//! The operation comes from the model: `metadata.annotations."spgen.operation"`
//! when the query declares one, else its `result` shape (`result.type: array`
//! *is* a collection read). The blueprint is fixed shape — the oracle declares
//! no `operations/0`, so `Blueprint.validate_operation/4` refuses `--template`
//! here: a run never overrides what the model states.
//!
//! `import Ecto.Query` is NOT managed here: only the implementing body knows
//! whether it speaks query macros, and an unused import is a compile warning
//! this tool must not manufacture. Whoever writes the body owns its imports.

use sparch_model::ElementKind;

use crate::blueprints::read_model::ReadModel;
use crate::context::{Context, Operation};
use crate::elixir::{ElixirFile, Rank};
use crate::plan::{Blueprint, Dependency, FilePlan, Placement, Stale, Unit, UnitId};

const PATH: &str =
    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/queries/<_query>.ex";
const MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<Query>";
const READ_MODEL_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel";
const QUERY_BUILDER: &str = "Sportipedia.Support.JSONAPI.QueryBuilder";
/// The scaffold's unimplemented body — `Query.marker?/1`.
const MARKER: &str = "raise \"TODO";

pub struct Query;

impl Query {
    /// The query module's file path (used as a `requires` gate) —
    /// `Query.module_file/1`.
    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(PATH)
    }

    /// The query module's name template (the public API calls through it) —
    /// `Query.module_template/0`.
    pub fn module_template() -> &'static str {
        MODULE
    }
}

impl Blueprint for Query {
    fn name(&self) -> &'static str {
        "query"
    }

    fn description(&self) -> Option<&'static str> {
        Some("Generates a query module for a query element")
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Query]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(PATH, "new/1 over read model")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        vec![FilePlan::new(
            ctx.render_or_panic(PATH),
            Some(ctx.render_or_panic(MODULE)),
            units(ctx),
        )]
    }

    /// A collection query delegates to the read model, so the read model is
    /// the citizen this blueprint's code calls. A read query leaves its body
    /// to the spec and calls nothing yet — `Query.dependencies/1`.
    fn dependencies(&self, ctx: &Context) -> Vec<Dependency> {
        if !is_collection(ctx) {
            return Vec::new();
        }
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
}

fn is_collection(ctx: &Context) -> bool {
    ctx.operation == Some(Operation::Collection)
}

/// `Query.doc/1` — the model's own words, or the blueprint's own marker.
fn doc(ctx: &Context) -> String {
    ctx.description()
        .map(str::to_string)
        .unwrap_or_else(|| format!("TODO: describe the {} query", ctx.element.name))
}

/// `Query.param_type/1` — a collection takes the parsed JSON:API config, a
/// read over declared parameters takes the string it addresses, and a read
/// the model gives no parameters for takes a map.
fn param_type(ctx: &Context) -> &'static str {
    if is_collection(ctx) {
        "JSONAPI.Config.t()"
    } else if !ctx.one_of_params().is_empty() {
        "String.t()"
    } else {
        "map()"
    }
}

/// The read model as the delegating body names it, through its alias —
/// `Query.read_model/1`.
fn read_model(ctx: &Context) -> String {
    format!("{}ReadModel", Context::pascal(&ctx.constituent))
}

/// Prose through the placeholder engine, so an irregular stem stays right:
/// one apparatus, several apparatuses — `<> "s"` on the constituent would not
/// be. — `Query.plural/1`
fn plural(ctx: &Context) -> String {
    ctx.render_or_panic("<domain_object>s")
}

/// The delegating body of a declared collection read — no macros, no TODO.
/// `Query.def_block/1`.
fn def_block(ctx: &Context) -> String {
    format!(
        "@doc \"\"\"\nCreates a new query to fetch {}.\n\"\"\"\n@spec new({}) :: Ecto.Query.t()\ndef new(query) do\n  QueryBuilder.build(query, {})\nend",
        plural(ctx),
        param_type(ctx),
        read_model(ctx)
    )
}

/// The scaffold of a read whose body the spec writes. The marker is a
/// warning-free `TODO:`: an unused parameter stays underscore-prefixed until
/// the body implements the query.
fn marker_block(ctx: &Context) -> String {
    format!(
        "@doc \"\"\"\nCreates a new query to fetch {}.\n\"\"\"\n@spec new({}) :: Ecto.Query.t()\ndef new(_params) do\n  # TODO: construct and return the query from the read model\n  raise \"TODO: implement {} query (see the feature spec)\"\nend",
        plural(ctx),
        param_type(ctx),
        ctx.element.name
    )
}

/// `Query.marker?/1` — the scaffold's `raise "TODO …"`, which is exactly the
/// file this blueprint must not push aliases into.
fn marker_in(file: &ElixirFile) -> bool {
    file.text().contains(MARKER)
}

// ------------------------------------------------------------------- units

fn units(ctx: &Context) -> Vec<Unit> {
    let mut units = vec![moduledoc_unit(ctx), def_unit(ctx)];
    units.extend(alias_units(ctx));
    units
}

fn moduledoc_unit(ctx: &Context) -> Unit {
    let doc = doc(ctx);
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

/// `Query.def_present?/2` — a collection body is present only when it
/// actually reads: a marker an earlier run left there counts as missing, so
/// it reaches `stale` and is reported, never appended as a second clause
/// (which would shadow the first). A read query's marker IS the delivery, so
/// `new/1` being defined is enough.
fn def_unit(ctx: &Context) -> Unit {
    let collection = is_collection(ctx);
    let render = if collection {
        def_block(ctx)
    } else {
        marker_block(ctx)
    };
    let notice = stale_notice(ctx);
    // the oracle carries `stale:` on every query's `new/1` unit; for a read
    // query `stale_body/2` answers with no detail, which is what keeps its
    // marker out of the report
    let stale: Stale = Some(Box::new(move |file: &ElixirFile| {
        if !collection || !file.has_def("new", 1) || !marker_in(file) {
            Vec::new()
        } else {
            vec![notice.clone()]
        }
    }));
    Unit {
        id: UnitId::Def("new".to_string(), 1),
        check: Box::new(move |f| f.has_def("new", 1) && (!collection || !marker_in(f))),
        render: Box::new(move || render.clone()),
        place: Placement::BodyEnd,
        requires: Vec::new(),
        stale,
    }
}

/// `Query.stale_body/2`'s detail — the merge never rewrites a line, so a body
/// an earlier run left as a marker stays standing after the model declares
/// the read it is. The tool owns the notice, the operator owns the edit.
fn stale_notice(ctx: &Context) -> String {
    format!(
        "new/1 still raises the marker the scaffold left — a collection read needs no spec work: replace the body with QueryBuilder.build(query, {}) and alias that read model and {QUERY_BUILDER}",
        read_model(ctx)
    )
}

/// The aliases a delegating body names — `Query.alias_units/1`. A TODO body
/// names nothing, and an unused alias is a compile warning this tool must not
/// manufacture, so a read query gets none.
fn alias_units(ctx: &Context) -> Vec<Unit> {
    if !is_collection(ctx) {
        return Vec::new();
    }
    let read_model_full = ctx.render_or_panic(READ_MODEL_MODULE);
    vec![
        alias_unit(read_model_full, read_model_gate(ctx)),
        alias_unit(QUERY_BUILDER.to_string(), Vec::new()),
    ]
}

fn alias_unit(module: String, requires: Vec<(String, String)>) -> Unit {
    let check_module = module.clone();
    let render = format!("alias {module}");
    Unit {
        id: UnitId::Alias(module.clone()),
        // a marker body names nothing yet: the unit counts as present so the
        // tool never aliases into a file that raises
        check: Box::new(move |f| f.has_alias(&check_module) || marker_in(f)),
        render: Box::new(move || render.clone()),
        requires,
        place: Placement::Head {
            rank: Rank::Alias,
            alias_sort_key: Some(module),
        },
        stale: None,
    }
}

/// The read model must be generated before the query may name it —
/// `Query.alias_units`' `requires` of `[{ReadModel.module_file(c), reason}]`.
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
            .resolve(name, &[ElementKind::Query])
            .expect("fixture query");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn units_for(name: &str) -> Vec<Unit> {
        Query.plans(&ctx_for(name)).remove(0).units
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

    fn labels(units: &[Unit]) -> Vec<String> {
        units.iter().map(|u| u.id.label()).collect()
    }

    #[test]
    fn a_read_query_derives_its_operation_from_the_result_shape() {
        // no `spgen.operation` annotation and `result.type: object` — read
        let ctx = ctx_for("read-widget");
        assert_eq!(ctx.operation, Some(Operation::Read));
        assert_eq!(
            Query::module_file(&ctx),
            "services/api/lib/sportipedia/catalog/equipment/widget/queries/read_widget.ex"
        );
        assert_eq!(
            ctx.render_or_panic(Query::module_template()),
            "Sportipedia.Catalog.Equipment.Widget.Queries.ReadWidget"
        );
    }

    #[test]
    fn a_declared_collection_wins_over_the_shape_and_pulls_the_read_model() {
        let ctx = ctx_for("list-widgets");
        assert_eq!(ctx.operation, Some(Operation::Collection));
        let deps = Query.dependencies(&ctx);
        assert_eq!(deps.len(), 1, "the delegating body calls the read model");
        assert_eq!(deps[0].blueprint_name, "read_model");
        assert_eq!(deps[0].element.name, "widget");
        assert!(
            Query::module_file(&ctx).ends_with("queries/list_widgets.ex"),
            "the file name is the snake-cased query name"
        );
    }

    #[test]
    fn a_read_query_calls_nothing_yet() {
        assert!(Query.dependencies(&ctx_for("read-widget")).is_empty());
    }

    #[test]
    fn the_read_body_is_the_marker_and_no_alias_lands() {
        let units = units_for("read-widget");
        assert_eq!(labels(&units), vec!["moduledoc", "new/1"]);
        assert_eq!(
            render(&units, "moduledoc"),
            "@moduledoc \"\"\"\nRetrieve a single widget by its id or slug\n\"\"\""
        );
        assert_eq!(
            render(&units, "new/1"),
            "@doc \"\"\"\nCreates a new query to fetch widgets.\n\"\"\"\n@spec new(String.t()) :: Ecto.Query.t()\ndef new(_params) do\n  # TODO: construct and return the query from the read model\n  raise \"TODO: implement read-widget query (see the feature spec)\"\nend"
        );
    }

    #[test]
    fn the_collection_body_delegates_with_its_two_aliases() {
        let units = units_for("list-widgets");
        assert_eq!(
            labels(&units),
            vec![
                "moduledoc",
                "new/1",
                "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel",
                "alias Sportipedia.Support.JSONAPI.QueryBuilder",
            ]
        );
        assert_eq!(
            render(&units, "new/1"),
            "@doc \"\"\"\nCreates a new query to fetch widgets.\n\"\"\"\n@spec new(JSONAPI.Config.t()) :: Ecto.Query.t()\ndef new(query) do\n  QueryBuilder.build(query, WidgetReadModel)\nend"
        );
        assert_eq!(
            render(
                &units,
                "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel"
            ),
            "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel"
        );

        let read_model_alias = unit(
            &units,
            "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel",
        );
        assert_eq!(
            read_model_alias.requires,
            vec![(
                "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex".to_string(),
                "read model not generated (sparch read_model)".to_string(),
            )]
        );
        // the shared support module is not a citizen, so nothing gates it
        assert!(
            unit(&units, "alias Sportipedia.Support.JSONAPI.QueryBuilder")
                .requires
                .is_empty()
        );
    }

    #[test]
    fn an_irregular_stem_stays_right_through_the_placeholder_engine() {
        // one apparatus, several apparatuses — `<> "s"` would not be
        let units = units_for("read-apparatus");
        assert!(render(&units, "new/1").contains("fetch apparatuses."));
        assert!(render(&units, "new/1").contains("@spec new(String.t())"));

        let units = units_for("list-apparatuses");
        assert!(render(&units, "new/1").contains("Creates a new query to fetch apparatuses."));
        assert!(render(&units, "new/1").contains("QueryBuilder.build(query, ApparatusReadModel)"));
        assert!(
            render(&units, "moduledoc")
                .contains("List all apparatus with filtering, sorting, and pagination")
        );
    }

    #[test]
    fn the_parameter_type_follows_the_declared_parameters() {
        // a read over `parameters.oneOf` names the string it addresses; a
        // collection declares `parameters.properties` instead and takes the
        // parsed config; a read with nothing declared takes a map
        let ctx = ctx_for("read-widget");
        assert_eq!(
            ctx.one_of_params(),
            vec!["id".to_string(), "slug".to_string()]
        );
        assert_eq!(param_type(&ctx), "String.t()");
        assert_eq!(param_type(&ctx_for("list-widgets")), "JSONAPI.Config.t()");

        // a read the model gives no parameters for is the third branch
        let read_ctx = ctx_for("read-widget");
        let mut bare = read_ctx.element.clone();
        bare.doc = serde_json::json!({"kind": "query", "name": "read-widget"});
        let ctx = read_ctx.with_element(&bare);
        assert!(ctx.one_of_params().is_empty());
        assert_eq!(param_type(&ctx), "map()");
    }

    #[test]
    fn a_marker_body_counts_as_a_complete_read_but_never_as_a_collection() {
        let text = "defmodule M do\n  def new(_params) do\n    raise \"TODO: implement list-widgets query (see the feature spec)\"\n  end\nend\n";
        let file = ElixirFile::parse(text);
        let read_units = units_for("read-widget");
        let collection_units = units_for("list-widgets");

        // the read query's marker IS the delivery
        assert!((unit(&read_units, "new/1").check)(&file));
        // the collection's marker is not: it reaches stale and is reported
        assert!(!(unit(&collection_units, "new/1").check)(&file));
        let details = (collection_units
            .iter()
            .find(|u| u.id.label() == "new/1")
            .and_then(|u| u.stale.as_ref())
            .map(|s| s(&file)))
        .unwrap_or_default();
        assert_eq!(details.len(), 1);
        assert!(details[0].contains("QueryBuilder.build(query, WidgetReadModel)"));
        assert!(
            details[0]
                .contains("alias that read model and Sportipedia.Support.JSONAPI.QueryBuilder")
        );

        // and the aliases a marker body names nothing for stay unrequested
        let alias = unit(
            &collection_units,
            "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel",
        );
        assert!((alias.check)(&file), "a marker file is not aliased into");
    }

    #[test]
    fn a_delegating_body_is_complete_and_stale_reports_nothing() {
        let text = "defmodule M do\n  def new(query) do\n    QueryBuilder.build(query, WidgetReadModel)\n  end\nend\n";
        let file = ElixirFile::parse(text);
        let units = units_for("list-widgets");
        assert!((unit(&units, "new/1").check)(&file));
        let stale = unit(&units, "new/1")
            .stale
            .as_ref()
            .expect("a collection carries a stale check");
        assert!(stale(&file).is_empty());
    }

    #[test]
    fn a_missing_body_is_not_stale_and_a_reads_marker_reports_nothing() {
        let empty = ElixirFile::parse("defmodule M do\nend\n");
        let units = units_for("list-widgets");
        let stale = unit(&units, "new/1")
            .stale
            .as_ref()
            .expect("a def carries a stale check");
        assert!(
            stale(&empty).is_empty(),
            "nothing standing yet means the body is placed, not reported"
        );

        // the read query's marker is the delivery, so it never reaches Outdated
        let read_units = units_for("read-widget");
        let marker = ElixirFile::parse(
            "defmodule M do\n  def new(_params) do\n    raise \"TODO: implement read-widget query (see the feature spec)\"\n  end\nend\n",
        );
        let stale = unit(&read_units, "new/1")
            .stale
            .as_ref()
            .expect("a def carries a stale check");
        assert!(stale(&marker).is_empty());
    }

    #[test]
    fn the_query_file_is_unit_created_and_module_checked() {
        let plan = Query.plans(&ctx_for("list-widgets")).remove(0);
        assert!(plan.unit_created);
        assert!(plan.format);
        assert!(!plan.requires_describe);
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.Catalog.Equipment.Widget.Queries.ListWidgets")
        );
    }

    #[test]
    fn the_blueprint_is_fixed_shape() {
        // the oracle declares no `operations/0`, so `--template` is refused
        // and the operation is the model's declaration alone
        assert!(Query.is_fixed());
        assert!(!Query.optional_template());
        assert!(Query.operations().is_empty());
    }
}
