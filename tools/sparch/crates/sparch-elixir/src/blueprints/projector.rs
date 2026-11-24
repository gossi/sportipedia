use sparch_model::ElementKind;

use crate::blueprints::event::Event;
use crate::blueprints::internal_api::InternalApi;
use crate::blueprints::read_model::ReadModel;
use crate::context::{Context, Operation};
use crate::elixir::Rank;
use crate::plan::{Blueprint, FilePlan, MacroPredicate, Placement, Unit, UnitId};
use crate::templates;

const PATH: &str =
    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/projector.ex";
const MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Projector";
const READ_MODEL_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel";
const INTERNAL_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal";
const EVENT_MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>";

pub struct Projector;

impl Projector {
    pub fn module_template() -> &'static str {
        MODULE
    }

    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(PATH)
    }

    pub fn projection_name(ctx: &Context) -> String {
        ctx.render_or_panic("<_composite>.<domain_object>_projection")
    }
}

impl Blueprint for Projector {
    fn name(&self) -> &'static str {
        "projector"
    }

    fn description(&self) -> Option<&'static str> {
        Some("Generates a projector clause for an event and registers the projector")
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Event]
    }

    fn is_fixed(&self) -> bool {
        false
    }

    fn operations(&self) -> Vec<Operation> {
        vec![
            Operation::Create,
            Operation::Update,
            Operation::Delete,
            Operation::None,
        ]
    }

    fn optional_template(&self) -> bool {
        true
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(PATH, "projection clause per event")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        let mut plan = FilePlan::new(
            ctx.render_or_panic(PATH),
            Some(ctx.render_or_panic(MODULE)),
            units(ctx),
        );
        plan.unit_created = true;
        vec![plan]
    }
}

fn units(ctx: &Context) -> Vec<Unit> {
    let event_pascal = Context::pascal(&ctx.element.name);
    let effect = ctx.effect_for_event(&ctx.element.name);

    let mut units: Vec<Unit> = Vec::new();

    {
        let doc = format!(
            "@moduledoc \"\"\"\nProjects {} events to the {} read model.\n\"\"\"",
            ctx.constituent, ctx.constituent
        );
        units.push(Unit {
            id: UnitId::Moduledoc,
            check: Box::new(|f| f.has_moduledoc()),
            render: Box::new(move || doc.clone()),
            place: Placement::Head {
                rank: Rank::Moduledoc,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        });
    }

    let render = use_block(ctx);
    units.push(Unit {
        id: UnitId::Use("Commanded.Projections.Ecto".into()),
        check: Box::new(|f| f.has_use("Commanded.Projections.Ecto")),
        render: Box::new(move || render.clone()),
        place: Placement::Head {
            rank: Rank::Use,
            alias_sort_key: None,
        },
        requires: Vec::new(),
        stale: None,
    });

    units.push(alias_unit(
        &ctx.render_or_panic(READ_MODEL_MODULE),
        read_model_gate(ctx),
    ));
    units.push(alias_unit(
        &ctx.render_or_panic(INTERNAL_MODULE),
        internal_gate(ctx),
    ));
    units.push(alias_unit(
        &ctx.render_or_panic(EVENT_MODULE),
        event_gate(ctx),
    ));

    match effect {
        None => units,
        Some(Operation::None) => units,
        Some(effect) => {
            units.push(clause_unit(ctx, &event_pascal, effect));
            units
        }
    }
}

fn use_block(ctx: &Context) -> String {
    let sub = Context::pascal(&ctx.subdomain);
    let projection = Projector::projection_name(ctx);
    format!(
        "  use Commanded.Projections.Ecto,\n    application: Sportipedia.{sub},\n    repo: Sportipedia.{sub}.Repo,\n    name: \"{projection}\",\n    schema_prefix: \"{}\",\n    consistency: :strong",
        ctx.subdomain
    )
    .trim_end()
    .to_string()
}

fn alias_unit(module: &str, requires: Vec<(String, String)>) -> Unit {
    let check_module = module.to_string();
    let render = format!("alias {module}");
    Unit {
        id: UnitId::Alias(module.to_string()),
        check: Box::new(move |f| f.has_alias(&check_module)),
        render: Box::new(move || render.clone()),
        requires,
        place: Placement::Head {
            rank: Rank::Alias,
            alias_sort_key: Some(module.to_string()),
        },
        stale: None,
    }
}

fn clause_unit(ctx: &Context, event_pascal: &str, effect: Operation) -> Unit {
    let key = format!("{event_pascal}{{}}");
    let check_key = key.clone();
    let render = clause(ctx, effect, event_pascal);
    Unit {
        id: UnitId::Project(ctx.element.name.clone()),
        check: Box::new(move |f| f.has_entry("project", &check_key)),
        render: Box::new(move || render.clone()),
        requires: {
            let mut gates = read_model_gate(ctx);
            gates.extend(internal_gate(ctx));
            gates
        },
        place: Placement::AfterMacro {
            macro_name: "project".into(),
            predicate: MacroPredicate::Any,
            fallback: Box::new(Placement::BodyEnd),
        },
        stale: None,
    }
}

fn clause(ctx: &Context, effect: Operation, event_pascal: &str) -> String {
    let doc = match effect {
        Operation::Update => format!(
            "Projects an {event_pascal} event to update the {} read model.",
            ctx.constituent
        ),
        Operation::Delete => format!(
            "Projects an {event_pascal} event to hard-delete the {} read model.",
            ctx.constituent
        ),
        _ => format!(
            "Projects an {event_pascal} event to the {} read model.",
            ctx.constituent
        ),
    };

    let body = clause_body(ctx, effect, event_pascal);
    format!(
        "@doc \"\"\"\n{doc}\n\"\"\"\nproject %{event_pascal}{{}} = event, _metadata, fn multi ->\n{}\nend",
        templates::indent(body.trim_end(), 2)
    )
}

/// One set edge an event writes: the clause label, the relation
/// property, the event's array field, the join storage, and the two
/// foreign-key columns. Only plain (not `join_model`) `many_to_many`
/// can be written as a set; a join model owns its rows through its own
/// commands and validate refuses a parent set for those.
struct SetEdge {
    clause: String,
    property: String,
    field: String,
    table: String,
    owner_col: String,
    other_col: String,
    prefix: String,
}

fn replace_units(ctx: &Context) -> Vec<SetEdge> {
    let Some(rm) = &ctx.read_model else {
        return Vec::new();
    };
    let clause = ctx.element.name.replace('-', "_");
    let mut out = Vec::new();
    for f in ctx.fields.iter().filter(|f| f.name != "id") {
        for p in sparch_model::fields(rm) {
            let Some(rel) = &p.relation else { continue };
            if rel.kind != sparch_model::RelationKind::ManyToMany || rel.join_model.is_some() {
                continue;
            }
            if !sparch_model::field_matches_property(&f.name, &p) {
                continue;
            }
            let table = rel
                .join_table
                .clone()
                .unwrap_or_else(|| super::read_model::derive_join_table(&rm.name, &rel.to));
            out.push(SetEdge {
                clause: clause.clone(),
                property: p.name.clone(),
                field: f.name.clone(),
                table,
                owner_col: format!(
                    "{}_id",
                    sparch_model::Name::parse(&rm.name).render(sparch_model::Case::Snake)
                ),
                other_col: format!(
                    "{}_id",
                    sparch_model::Name::parse(&rel.to).render(sparch_model::Case::Snake)
                ),
                prefix: ctx.subdomain.clone(),
            });
        }
    }
    out
}

/// One `Ecto.Multi.run` step replacing (or, on a delete, clearing) the
/// link rows of one set edge. Delete then insert is replay-safe because
/// the event carries the whole set. `at` is the indentation of the
/// surrounding pipeline step.
fn replace_step(edge: &SetEdge, at: usize, cleanup_only: bool) -> String {
    let SetEdge {
        clause,
        property,
        field,
        table,
        owner_col,
        other_col,
        prefix,
    } = edge;
    let pad = " ".repeat(at);
    let inner = " ".repeat(at + 2);
    let name = if cleanup_only {
        format!("{clause}_{property}_cleanup")
    } else {
        format!("{clause}_{property}")
    };
    let body = if cleanup_only {
        format!(
            "{inner}  {{:ok, repo.delete_all(from(r in \"{table}\", where: r.{owner_col} == ^event.id), prefix: \"{prefix}\")}}\n{inner}end)"
        )
    } else {
        format!(
            "{inner}  rows = Enum.map(event.{field}, fn id -> %{{ {owner_col}: event.id, {other_col}: id }} end)\n{inner}  {{_, nil}} = repo.delete_all(from(r in \"{table}\", where: r.{owner_col} == ^event.id), prefix: \"{prefix}\")\n{inner}  {{:ok, repo.insert_all(\"{table}\", rows, prefix: \"{prefix}\")}}\n{inner}end)"
        )
    };
    format!("\n{pad}|> Ecto.Multi.run(:{name}, fn repo, _ ->\n{body}")
}

fn clause_body(ctx: &Context, effect: Operation, event_pascal: &str) -> String {
    let read_model = format!("{}ReadModel", Context::pascal(&ctx.constituent));
    let internal = format!("{}Internal", Context::pascal(&ctx.constituent));
    let var = ctx.constituent.clone();
    let label = ctx.element.name.replace('-', "_");
    let renames = ctx.column_renames();
    let replaces = replace_units(ctx);

    // the projector's single translation: event keys whose relation
    // stores into an overridden column. A derived column equals the event
    // key and produces no step, so unchanged models keep today's text.
    let mut apply = String::new();
    for (field, column) in &renames {
        apply.push_str(&format!(
            " |> Map.put(:{column}, event.{field}) |> Map.delete(:{field})"
        ));
    }
    match effect {
        Operation::Update => {
            let mut steps = String::new();
            for edge in &replaces {
                steps.push_str(&replace_step(edge, 4, false));
            }
            format!(
                "case {internal}.{var}_by_id(event.id) do\n  nil ->\n    multi\n\n  %{read_model}{{}} = {var} ->\n    attrs = {event_pascal}.get_changes(event){apply}\n\n    multi\n    |> Ecto.Multi.update(\n      :{label},\n      {read_model}.update_changeset({var}, attrs)\n    ){steps}\nend"
            )
        }
        Operation::Delete => {
            let mut steps = String::new();
            for edge in &replaces {
                steps.push_str(&replace_step(edge, 4, true));
            }
            format!(
                "case {internal}.{var}_by_id(event.id) do\n  nil ->\n    multi\n\n  %{read_model}{{}} = {var} ->\n    multi\n    |> Ecto.Multi.delete(:{label}, {var}){steps}\nend"
            )
        }
        _ => {
            let mut steps = String::new();
            for edge in &replaces {
                steps.push_str(&replace_step(edge, 0, false));
            }
            if renames.is_empty() {
                format!(
                    "multi\n|> Ecto.Multi.insert(\n  :{label},\n  {read_model}.insert_changeset(%{read_model}{{}}, Map.from_struct(event))\n){steps}"
                )
            } else {
                format!(
                    "attrs = event |> Map.from_struct(){apply}\n\nmulti\n|> Ecto.Multi.insert(\n  :{label},\n  {read_model}.insert_changeset(%{read_model}{{}}, attrs)\n){steps}"
                )
            }
        }
    }
}

fn read_model_gate(ctx: &Context) -> Vec<(String, String)> {
    vec![(
        ReadModel::module_file(ctx),
        "read model not generated (sparch read_model)".to_string(),
    )]
}

fn internal_gate(ctx: &Context) -> Vec<(String, String)> {
    vec![(
        InternalApi::module_file(ctx),
        "internal API not generated (sparch internal_api)".to_string(),
    )]
}

fn event_gate(ctx: &Context) -> Vec<(String, String)> {
    vec![(
        Event::module_file(ctx),
        "event not generated (sparch event)".to_string(),
    )]
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use crate::elixir::ElixirFile;
    use sparch_model::Model;
    use std::path::PathBuf;

    fn ctx_for(event: &str) -> Context {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model
            .resolve(event, &[ElementKind::Event])
            .expect("fixture event");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn unit_texts(units: &[Unit]) -> Vec<(String, String)> {
        units.iter().map(|u| (u.id.label(), (u.render)())).collect()
    }

    fn units_for(event: &str) -> Vec<Unit> {
        Projector.plans(&ctx_for(event)).remove(0).units
    }

    #[test]
    fn paths_modules_and_projection_name_render_as_the_model_expects() {
        let ctx = ctx_for("widget-created");
        assert_eq!(
            Projector::module_file(&ctx),
            "services/api/lib/sportipedia/catalog/equipment/widget/projector.ex"
        );
        let plan = &Projector.plans(&ctx)[0];
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.Catalog.Equipment.Widget.WidgetProjector")
        );
        assert!(plan.unit_created);
        assert_eq!(
            Projector::projection_name(&ctx),
            "equipment.widget_projection"
        );
    }

    #[test]
    fn unit_ids_and_order_match_the_model() {
        let labels: Vec<String> = units_for("widget-created")
            .iter()
            .map(|u| u.id.label())
            .collect();
        assert_eq!(
            labels,
            vec![
                "moduledoc",
                "use Commanded.Projections.Ecto",
                "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel",
                "alias Sportipedia.Catalog.Equipment.Widget.WidgetInternal",
                "alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated",
                "project widget-created",
            ]
        );
    }

    #[test]
    fn an_undeclared_or_none_event_plans_no_clause() {
        let noted: Vec<String> = units_for("widget-noted")
            .iter()
            .map(|u| u.id.label())
            .collect();
        assert!(
            !noted.iter().any(|l| l.starts_with("project ")),
            "{noted:?}"
        );
        assert_eq!(noted.len(), 5, "the five base units, no clause");
    }

    #[test]
    fn the_create_clause_is_the_insert_projection() {
        let texts = unit_texts(&units_for("widget-created"));
        let clause = texts
            .iter()
            .find(|(l, _)| l == "project widget-created")
            .map(|(_, t)| t.clone())
            .expect("the clause");
        assert_eq!(
            clause,
            "@doc \"\"\"\nProjects an WidgetCreated event to the widget read model.\n\"\"\"\nproject %WidgetCreated{} = event, _metadata, fn multi ->\n  multi\n  |> Ecto.Multi.insert(\n    :widget_created,\n    WidgetReadModel.insert_changeset(%WidgetReadModel{}, Map.from_struct(event))\n  )\nend"
        );
    }

    #[test]
    fn the_update_clause_merges_the_event_changes() {
        let texts = unit_texts(&units_for("widget-edited"));
        let clause = texts
            .iter()
            .find(|(l, _)| l == "project widget-edited")
            .map(|(_, t)| t.clone())
            .expect("the clause");
        assert!(
            clause.contains("attrs = WidgetEdited.get_changes(event)"),
            "the get_changes/1 contract of the update event:\n{clause}"
        );
        assert!(clause.contains("WidgetReadModel.update_changeset(widget, attrs)"));
        assert!(clause.starts_with(
            "@doc \"\"\"\nProjects an WidgetEdited event to update the widget read model."
        ));
    }

    #[test]
    fn the_delete_clause_removes_the_row() {
        let texts = unit_texts(&units_for("widget-archived"));
        let clause = texts
            .iter()
            .find(|(_, t)| t.contains("project %WidgetArchived{}"))
            .map(|(_, t)| t.clone())
            .expect("the clause");
        assert!(clause.contains("multi\n      |> Ecto.Multi.delete(:widget_archived, widget)"));
        assert!(clause.contains("hard-delete the widget read model"));
    }

    #[test]
    fn the_use_block_names_the_projection_and_the_schema_prefix() {
        let texts = unit_texts(&units_for("widget-created"));
        let use_ = texts
            .iter()
            .find(|(l, _)| l == "use Commanded.Projections.Ecto")
            .map(|(_, t)| t.clone())
            .expect("the use");
        assert_eq!(
            use_,
            "  use Commanded.Projections.Ecto,\n    application: Sportipedia.Catalog,\n    repo: Sportipedia.Catalog.Repo,\n    name: \"equipment.widget_projection\",\n    schema_prefix: \"catalog\",\n    consistency: :strong"
        );
    }

    #[test]
    fn the_named_citizens_gate_the_alias_and_the_clause() {
        let units = units_for("widget-created");
        let find = |label: &str| units.iter().find(|u| u.id.label() == label).expect(label);
        assert_eq!(
            find("alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel").requires,
            vec![(
                "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex".to_string(),
                "read model not generated (sparch read_model)".to_string(),
            )]
        );
        assert_eq!(
            find("alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated").requires,
            vec![(
                "services/api/lib/sportipedia/catalog/equipment/widget/events/widget_created.ex"
                    .to_string(),
                "event not generated (sparch event)".to_string(),
            )]
        );
        let clause = find("project widget-created");
        assert_eq!(clause.requires.len(), 2, "read model and internal API");
    }

    #[test]
    fn the_finished_projector_file_reads_fully_present() {
        let text = "defmodule Sportipedia.Catalog.Equipment.Widget.WidgetProjector do\n  @moduledoc \"\"\"\n  Projects widget events to the widget read model.\n  \"\"\"\n  use Commanded.Projections.Ecto,\n    application: Sportipedia.Catalog,\n    repo: Sportipedia.Catalog.Repo,\n    name: \"equipment.widget_projection\",\n    schema_prefix: \"catalog\",\n    consistency: :strong\n  alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated\n  alias Sportipedia.Catalog.Equipment.Widget.WidgetInternal\n  alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel\n\n  @doc \"\"\"\n  Projects an WidgetCreated event to the widget read model.\n  \"\"\"\n  project %WidgetCreated{} = event, _metadata, fn multi ->\n    multi\n    |> Ecto.Multi.insert(\n      :widget_created,\n      WidgetReadModel.insert_changeset(%WidgetReadModel{}, Map.from_struct(event))\n    )\n  end\nend\n";
        let file = ElixirFile::parse(text);
        for unit in &units_for("widget-created") {
            assert!((unit.check)(&file), "{} must read present", unit.id.label());
        }
    }

    #[test]
    fn a_column_override_renames_the_event_key_in_the_create_clause() {
        let ctx = ctx_for("position-cataloged");
        let renames = ctx.column_renames();
        assert_eq!(
            renames,
            vec![(
                "instrument_id".to_string(),
                "installed_instrument_id".to_string()
            )]
        );
        assert!(
            !renames.iter().any(|(field, _)| field == "apparatus_id"),
            "the derived column is the event key itself — no translation"
        );
        let body = clause_body(&ctx, Operation::Create, "PositionCataloged");
        assert!(
            body.contains(
                "attrs = event |> Map.from_struct() |> Map.put(:installed_instrument_id, event.instrument_id) |> Map.delete(:instrument_id)"
            ),
            "{body}"
        );
        assert!(
            body.contains("insert_changeset(%PositionReadModel{}, attrs)"),
            "{body}"
        );
    }

    #[test]
    fn the_update_clause_renames_through_the_changes_pipeline() {
        let ctx = ctx_for("position-edited");
        let body = clause_body(&ctx, Operation::Update, "PositionEdited");
        assert!(
            body.contains(
                "attrs = PositionEdited.get_changes(event) |> Map.put(:installed_instrument_id, event.instrument_id) |> Map.delete(:instrument_id)"
            ),
            "{body}"
        );
    }

    #[test]
    fn a_set_edge_event_replaces_the_link_rows_in_the_multi() {
        let ctx = ctx_for("apparatus-tagged");
        let units = Projector.plans(&ctx).remove(0).units;
        let clause = units
            .iter()
            .find(|u| u.id.label() == "project apparatus-tagged")
            .expect("clause");
        let text = (clause.render)();
        assert!(
            text.contains("|> Ecto.Multi.run(:apparatus_tagged_tags, fn repo, _ ->"),
            "{text}"
        );
        assert!(
            text.contains("rows = Enum.map(event.tag_ids, fn id -> %{ apparatus_id: event.id, tag_id: id } end)"),
            "{text}"
        );
        assert!(
            text.contains("{_, nil} = repo.delete_all(from(r in \"apparatuses_tags\", where: r.apparatus_id == ^event.id), prefix: \"catalog\")"),
            "{text}"
        );
        assert!(
            text.contains(
                "{:ok, repo.insert_all(\"apparatuses_tags\", rows, prefix: \"catalog\")}"
            ),
            "{text}"
        );
    }

    #[test]
    fn an_event_without_set_edges_renders_no_replace_step() {
        let ctx = ctx_for("widget-created");
        let text = clause(&ctx, Operation::Create, "WidgetCreated");
        assert!(!text.contains("Multi.run"), "{text}");
        assert!(!text.contains("attrs ="), "no rename either: {text}");
    }
}
