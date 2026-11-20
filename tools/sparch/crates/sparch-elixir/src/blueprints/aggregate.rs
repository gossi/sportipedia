//! The aggregate module file — the executable transfer of
//! `docs/architecture/blueprints/backend/domain/aggregate.md`, ported from
//! `SpGen.Blueprint.Aggregate`
//! (`tools/spgen/lib/sp_gen/blueprint/aggregate.ex`).
//!
//! Generates the aggregate module (or appends to an existing one): state
//! fields and one `apply/2` clause per event of the aggregate — the body is
//! chosen by the operation the read model *declares*
//! (`spgen.operation.<event>`): `create` sets state, `update` merges
//! changes, `delete` terminates the aggregate with `nil`, and a declared
//! `none` (an audit fact) folds to the unchanged state. Events without any
//! declaration generate no clause and are reported as a model gap (the run
//! rows — see `engine::effect_gap_rows`).
//!
//! Fixed shape: the events drive everything, no `--template`.

use sparch_model::{Element, ElementKind};

use crate::blueprints::event::Event;
use crate::context::{Context, Operation};
use crate::elixir::Rank;
use crate::plan::{Blueprint, FilePlan, Placement, Unit, UnitId};

const PATH: &str =
    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/aggregate.ex";
const MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate";
const EVENT_MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>";

pub struct Aggregate;

impl Aggregate {
    /// The aggregate's module-name template (referenced by `AggregateTest`)
    /// — `Aggregate.module_template/0`.
    pub fn module_template() -> &'static str {
        MODULE
    }

    /// The aggregate module's file path for the element in `ctx` (used as a
    /// `requires` gate) — `Aggregate.module_file/1`.
    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(PATH)
    }
}

impl Blueprint for Aggregate {
    fn name(&self) -> &'static str {
        "aggregate"
    }

    fn description(&self) -> Option<&'static str> {
        Some("Generates the aggregate module with apply/2 clauses per event")
    }

    /// `Aggregate.source_kinds` — the aggregate reads its fold from the
    /// events, so a run driven from a command or an event names the same
    /// aggregate and generates the missing clause for just that fact.
    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![
            ElementKind::Aggregate,
            ElementKind::Command,
            ElementKind::Event,
        ]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(PATH, "typedstruct state with apply clauses")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        vec![FilePlan::new(
            ctx.render_or_panic(PATH),
            Some(ctx.render_or_panic(MODULE)),
            units(ctx),
        )]
    }
}

/// `Aggregate.moduledoc_text/1` — the model's own words when the aggregate
/// has them, the blueprint's TODO when it does not.
fn moduledoc_text(ctx: &Context) -> String {
    match ctx.description() {
        None => format!(
            "TODO: Aggregate representing a {} in the {}.",
            ctx.constituent,
            ctx.bounded_context()
        ),
        Some(desc) => desc.to_string(),
    }
}

// ------------------------------------------------------------------- units

fn units(ctx: &Context) -> Vec<Unit> {
    let events = ctx.model.events_of(&ctx.constituent);

    let mut units: Vec<Unit> = Vec::new();

    // @moduledoc
    {
        let doc = moduledoc_text(ctx);
        units.push(Unit {
            id: UnitId::Moduledoc,
            check: Box::new(|f| f.has_moduledoc()),
            render: Box::new(move || format!("@moduledoc \"\"\"\n{doc}\n\"\"\"")),
            place: Placement::Head {
                rank: Rank::Moduledoc,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        });
    }

    units.push(use_unit("TypedStruct"));

    units.extend(events.iter().map(|e| {
        let full = ctx.with_element(e).render_or_panic(EVENT_MODULE);
        let check_module = full.clone();
        let render = format!("alias {full}");
        Unit {
            id: UnitId::Alias(full.clone()),
            check: Box::new(move |f| f.has_alias(&check_module)),
            render: Box::new(move || render.clone()),
            requires: event_gate(ctx, e),
            place: Placement::Head {
                rank: Rank::Alias,
                alias_sort_key: Some(full),
            },
            stale: None,
        }
    }));

    units.extend(field_units(ctx));

    units.extend(
        events
            .iter()
            .filter_map(|e| {
                let effect = ctx.effect_for_event(&e.name)?;
                let key = event_key(ctx, e);
                let requires = event_gate(ctx, e);
                // plans are per-context: the clause text resolves now, the
                // way `FilePlan` documents the render's context dependency
                let render = apply_clause(ctx, e, effect);
                Some(Unit {
                    id: UnitId::Apply(e.name.clone()),
                    check: Box::new(move |f| f.has_def_head_arg("apply", 2, &key)),
                    render: Box::new(move || render.clone()),
                    requires,
                    place: Placement::AfterDef {
                        name: "apply".to_string(),
                        arity: 2,
                    },
                    stale: None,
                })
            })
            .collect::<Vec<_>>(),
    );

    units
}

/// `Aggregate.use_unit` — a `use` line in the directive block.
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

/// The event's own module file must exist before the aggregate may
/// reference it (alias + pattern match on its struct) — `event_gate/2`.
fn event_gate(ctx: &Context, event: &Element) -> Vec<(String, String)> {
    let path = Event::module_file(&ctx.with_element(event));
    let reason = format!(
        "event {} not generated (sparch event {})",
        event.name, event.name
    );
    vec![(path, reason)]
}

/// `event_key/2` — the rendered `%Event{}` head pattern the clause check
/// looks for, as `Source.render_arg` sees it: `WidgetCreated{}`.
fn event_key(ctx: &Context, event: &Element) -> String {
    let mut key = ctx.with_element(event).render_or_panic("<Event>");
    key.push_str("{}");
    key
}

fn field_units(ctx: &Context) -> Vec<Unit> {
    ctx.fields
        .iter()
        .map(|f| {
            let key = format!(":{}", f.name);
            // the aggregate's typedstruct states the fact's shape — no
            // `enforce:`, the fold never constructs through Vex
            let render = format!("field :{}, {}", f.name, Context::elixir_type(f));
            Unit {
                id: UnitId::Field(f.name.clone()),
                check: Box::new({
                    let key = key.clone();
                    move |file| file.has_entry("field", &key)
                }),
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

// --------------------------------------------------------------- clauses

/// The `apply/2` clause folding one event into the state — `apply_clause/3`.
/// Self-references inside the aggregate module go through `__MODULE__`:
/// by its expanded name the struct is not yet defined while compiling.
pub fn apply_clause(ctx: &Context, event: &Element, effect: Operation) -> String {
    let aggregate = "__MODULE__";
    let event_pascal = Context::pascal(&event.name);

    match effect {
        Operation::Update => format!(
            "def apply(%{aggregate}{{}} = aggregate, %{event_pascal}{{}} = event) do\n  changes = {event_pascal}.get_changes(event)\n\n  aggregate\n  |> Map.merge(changes)\nend"
        ),
        Operation::Delete => format!(
            "def apply(%{aggregate}{{}} = _aggregate, %{event_pascal}{{}} = _event) do\n  nil\nend"
        ),
        // declared not to materialize — the fact still flows through the
        // fold, it simply changes nothing
        Operation::None => format!(
            "def apply(%{aggregate}{{}} = aggregate, %{event_pascal}{{}} = _event) do\n  aggregate\nend"
        ),
        _ => {
            // create — the state is set from the event's facts, field by
            // field; the aggregate's own field list is the ledger
            let body = ctx
                .fields
                .iter()
                .map(|f| format!("      {}: event.{},", f.name, f.name))
                .collect::<Vec<_>>()
                .join("\n");
            // `String.replace_trailing(",", "")` — the literal's last line
            // carries no comma
            let body = body.strip_suffix(',').unwrap_or(&body);
            format!(
                "def apply(%{aggregate}{{}} = _aggregate, %{event_pascal}{{}} = event) do\n  %{aggregate}{{\n{body}\n  }}\nend"
            )
        }
    }
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
            .resolve(name, &[ElementKind::Aggregate])
            .expect("fixture aggregate");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn unit_texts(units: &[Unit]) -> Vec<(String, String)> {
        units.iter().map(|u| (u.id.label(), (u.render)())).collect()
    }

    #[test]
    fn paths_and_modules_render_like_the_oracle() {
        let ctx = ctx_for("widget");
        assert_eq!(
            Aggregate::module_file(&ctx),
            "services/api/lib/sportipedia/catalog/equipment/widget/aggregate.ex"
        );
        assert_eq!(
            ctx.render_or_panic(Aggregate::module_template()),
            "Sportipedia.Catalog.Equipment.Widget.WidgetAggregate"
        );
    }

    #[test]
    fn unit_ids_and_order_mirror_the_oracle() {
        let ctx = ctx_for("widget");
        let plans = Aggregate.plans(&ctx);
        let ids: Vec<String> = plans[0].units.iter().map(|u| u.id.label()).collect();
        // moduledoc, use, one alias per event of the constituent (sorted),
        // the state fields, one apply clause per DECLARED event
        assert_eq!(
            ids,
            vec![
                "moduledoc",
                "use TypedStruct",
                "alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetArchived",
                "alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated",
                "alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetEdited",
                "alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetNoted",
                "alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetRelabelled",
                "alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetRenameLogged",
                "field id",
                "field title",
                "field slug",
                "field archivedAt",
                "field coachId",
                "field description",
                "field label",
                "field teamId",
                "apply widget-archived",
                "apply widget-created",
                "apply widget-edited",
                "apply widget-noted",
                "apply widget-relabelled",
                "apply widget-rename-logged",
            ]
        );
    }

    #[test]
    fn every_unit_that_names_an_event_waits_for_its_module() {
        let ctx = ctx_for("widget");
        let plan = &Aggregate.plans(&ctx)[0];
        // the moduledoc/use/field units carry no gate; every alias and
        // every apply clause is gated on its event's module file
        for unit in &plan.units {
            let names_event = matches!(unit.id, UnitId::Alias(_) | UnitId::Apply(_));
            if names_event {
                assert_eq!(
                    unit.requires.len(),
                    1,
                    "{} must gate on the event",
                    unit.id.label()
                );
                assert!(
                    unit.requires[0].0.starts_with(
                        "services/api/lib/sportipedia/catalog/equipment/widget/events/"
                    )
                );
                assert!(unit.requires[0].1.contains("not generated (sparch event"));
            } else {
                assert!(
                    unit.requires.is_empty(),
                    "{} must not gate",
                    unit.id.label()
                );
            }
        }
    }

    #[test]
    fn field_lines_carry_no_enforce() {
        let ctx = ctx_for("widget");
        let texts = unit_texts(&Aggregate.plans(&ctx)[0].units);
        let field = texts
            .iter()
            .find(|(label, _)| label == "field title")
            .expect("the title field");
        assert_eq!(field.1, "field :title, String.t()");
        let id = texts
            .iter()
            .find(|(label, _)| label == "field id")
            .expect("the id field");
        assert_eq!(id.1, "field :id, String.t()");
    }

    #[test]
    fn apply_clauses_carry_the_exact_oracle_text_per_declared_effect() {
        let ctx = ctx_for("widget");
        let texts = unit_texts(&Aggregate.plans(&ctx)[0].units);
        let get = |label: &str| {
            texts
                .iter()
                .find(|(l, _)| l == label)
                .map(|(_, t)| t.clone())
                .expect("clause")
        };

        assert_eq!(
            get("apply widget-created"),
            "def apply(%__MODULE__{} = _aggregate, %WidgetCreated{} = event) do\n  %__MODULE__{\n      id: event.id,\n      title: event.title,\n      slug: event.slug,\n      archivedAt: event.archivedAt,\n      coachId: event.coachId,\n      description: event.description,\n      label: event.label,\n      teamId: event.teamId\n  }\nend"
        );
        assert_eq!(
            get("apply widget-edited"),
            "def apply(%__MODULE__{} = aggregate, %WidgetEdited{} = event) do\n  changes = WidgetEdited.get_changes(event)\n\n  aggregate\n  |> Map.merge(changes)\nend"
        );
        assert_eq!(
            get("apply widget-relabelled"),
            "def apply(%__MODULE__{} = aggregate, %WidgetRelabelled{} = event) do\n  changes = WidgetRelabelled.get_changes(event)\n\n  aggregate\n  |> Map.merge(changes)\nend"
        );
        assert_eq!(
            get("apply widget-archived"),
            "def apply(%__MODULE__{} = _aggregate, %WidgetArchived{} = _event) do\n  nil\nend"
        );
        assert_eq!(
            get("apply widget-noted"),
            "def apply(%__MODULE__{} = aggregate, %WidgetNoted{} = _event) do\n  aggregate\nend"
        );
        assert_eq!(
            get("apply widget-rename-logged"),
            "def apply(%__MODULE__{} = aggregate, %WidgetRenameLogged{} = _event) do\n  aggregate\nend"
        );
    }

    #[test]
    fn moduledoc_carries_the_models_words() {
        let ctx = ctx_for("widget");
        let texts = unit_texts(&Aggregate.plans(&ctx)[0].units);
        let doc = texts
            .iter()
            .find(|(label, _)| label == "moduledoc")
            .expect("moduledoc");
        assert_eq!(
            doc.1,
            "@moduledoc \"\"\"\nA piece of gym apparatus a coach catalogs for later reference\n\"\"\""
        );
    }

    #[test]
    fn a_run_from_an_event_element_folds_that_event_too() {
        // source_kinds [:aggregate, :command, :event]: `sparch aggregate
        // widget-created` plans the same aggregate from the fact
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let event = model
            .resolve("widget-created", &[ElementKind::Event])
            .expect("fixture event");
        let ctx = Context::build(&model, &event, &ContextOptions::default()).expect("context");
        let plan = &Aggregate.plans(&ctx)[0];
        assert_eq!(
            plan.path,
            "services/api/lib/sportipedia/catalog/equipment/widget/aggregate.ex"
        );
        assert!(
            plan.units
                .iter()
                .any(|u| u.id.label() == "apply widget-created")
        );
    }
}
