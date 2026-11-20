//! The aggregate's contribution to each event's test file — ported from
//! `SpGen.Blueprint.AggregateTest`
//! (`tools/spgen/lib/sp_gen/blueprint/aggregate_test.ex`).
//!
//! A `describe "Aggregate"` block per event, applying that fact to the
//! state. The fact under test decides where its test lives, so every event
//! of the aggregate gets its own apply test in its own event test file —
//! the event's own `describe "Event"` block already lives there, and the
//! projector's `describe "Projector"` joins it the same way this block
//! does. Events the read model never decided on have no generated apply
//! clause: no fold to test, and the run reports the open question instead.

use sparch_model::placeholders::Vars;
use sparch_model::{Element, ElementKind};

use crate::blueprints::aggregate::Aggregate;
use crate::blueprints::event::Event;
use crate::blueprints::test_case::{self, Describe, Options};
use crate::context::{Befield, Context, Operation};
use crate::plan::{Blueprint, FilePlan};
use crate::templates;

const TEST_PATH: &str = "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/events/<_event>_test.exs";
const TEST_MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>Test";

pub struct AggregateTest;

impl Blueprint for AggregateTest {
    fn name(&self) -> &'static str {
        "aggregate_test"
    }

    /// The oracle derives its sweep participation from the generator's
    /// head (`primary.accepts?`); the Rust sweep asks each ported module,
    /// so the companion names the kinds its head accepts.
    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![
            ElementKind::Aggregate,
            ElementKind::Command,
            ElementKind::Event,
        ]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(TEST_PATH, "aggregate fold test per event")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        ctx.aggregate_events()
            .into_iter()
            // an event nobody declared has no generated apply clause —
            // there is no fold to test
            .filter(|event| ctx.effect_for_event(&event.name).is_some())
            .map(|event| plan_for_event(ctx, &event))
            .collect()
    }
}

fn plan_for_event(ctx: &Context, event: &Element) -> FilePlan {
    let event_ctx = ctx.with_element(event);
    let mut extra_vars = Vars::new();
    extra_vars.insert("event".to_string(), event.name.clone());
    let body_event = event.clone();

    test_case::plan(
        ctx,
        Options {
            path_template: TEST_PATH,
            module_template: TEST_MODULE,
            extra_vars,
            alias_templates: vec![Aggregate::module_template()],
            alias_modules: vec![event_ctx.render_or_panic(Event::module_template())],
            requires: vec![
                (
                    Aggregate::module_file(ctx),
                    "aggregate not generated (sparch aggregate)".to_string(),
                ),
                (
                    Event::module_file(&event_ctx),
                    format!(
                        "event {} not generated (sparch event {})",
                        event.name, event.name
                    ),
                ),
            ],
            alias_requires: None,
            describes: vec![Describe {
                subject_template: "Aggregate",
                body: Box::new(move |c, subject| {
                    describe_body(c, subject, std::slice::from_ref(&body_event))
                }),
                alternates: vec!["<DomainObject>Aggregate"],
            }],
        },
    )
}

/// The `describe` body — `AggregateTest.describe_body/3`, heredoc
/// whitespace included.
pub fn describe_body(ctx: &Context, subject: &str, events: &[Element]) -> String {
    let aggregate = ctx.render_or_panic("<DomainObject>Aggregate");

    let tests: Vec<String> = events
        .iter()
        .map(|e| {
            let event_pascal = Context::pascal(&e.name);

            // the literal carries the EVENT's fields; the state it is
            // applied to is seeded with the id so update/delete clauses
            // have something to act on
            let fields: Vec<Befield> = sparch_model::fields(e)
                .iter()
                .map(Befield::from_field)
                .collect();
            let event_body = fields
                .iter()
                .map(|f| format!("{}: {}", f.name, templates::sample_value(ctx, f)))
                .collect::<Vec<_>>()
                .join(", ");

            format!(
                "test \"applies {} to aggregate state\" do\n  event = %{}{{{}}}\n\n  {}\nend",
                e.name,
                event_pascal,
                event_body,
                apply_test(ctx, &aggregate, e, &fields)
            )
        })
        .collect();

    let joined = tests.join("\n\n");
    format!(
        "describe \"{subject}\" do\n{}\nend",
        templates::indent(&joined, 2)
    )
}

fn apply_test(ctx: &Context, aggregate: &str, event: &Element, fields: &[Befield]) -> String {
    let seed = format!("%{aggregate}{{id: event.id}}");

    match ctx.effect_for_event(&event.name) {
        Some(Operation::Create) => format!(
            "result = {aggregate}.apply(%{aggregate}{{}}, event)\n\n{}",
            assertions(fields)
        ),
        Some(Operation::Delete) => {
            format!("result = {aggregate}.apply({seed}, event)\n\nassert is_nil(result)")
        }
        // the declared-none fact flows through: the state leaves unchanged
        Some(Operation::None) => {
            format!("state = {seed}\n\nassert {aggregate}.apply(state, event) == state")
        }
        _ => format!(
            "result = {aggregate}.apply({seed}, event)\n\n{}",
            assertions(fields)
        ),
    }
}

fn assertions(fields: &[Befield]) -> String {
    fields
        .iter()
        .map(|f| format!("assert result.{} == event.{}", f.name, f.name))
        .collect::<Vec<_>>()
        .join("\n      ")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use crate::elixir::ElixirFile;
    use crate::plan::UnitId;
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

    #[test]
    fn one_plan_per_declared_event_in_the_events_own_test_files() {
        let ctx = ctx_for("widget");
        let plans = AggregateTest.plans(&ctx);
        assert_eq!(plans.len(), 6, "widget has six declared events");
        for (plan, snake) in plans.iter().zip([
            "widget_archived",
            "widget_created",
            "widget_edited",
            "widget_noted",
            "widget_relabelled",
            "widget_rename_logged",
        ]) {
            assert_eq!(
                plan.path,
                format!(
                    "services/api/test/sportipedia/catalog/equipment/widget/events/{snake}_test.exs"
                )
            );
        }
        let module = plans[1].module.clone().unwrap();
        assert_eq!(
            module,
            "Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreatedTest"
        );
        assert!(plans[0].requires_describe);
        assert!(plans[0].unit_created);
    }

    #[test]
    fn the_plan_carries_both_gates_and_both_aliases() {
        let ctx = ctx_for("widget");
        let plan = &AggregateTest.plans(&ctx)[1]; // widget-created
        let ids: Vec<String> = plan.units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            ids,
            vec![
                "use Sportipedia.CatalogTestCase",
                "moduletag",
                "test_alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate",
                "test_alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated",
                "describe Aggregate",
            ]
        );
        // the aggregate module and the event module both gate the alias
        // and the describe
        let gate = &plan.units[2].requires;
        assert_eq!(
            gate,
            &vec![
                (
                    "services/api/lib/sportipedia/catalog/equipment/widget/aggregate.ex".to_string(),
                    "aggregate not generated (sparch aggregate)".to_string(),
                ),
                (
                    "services/api/lib/sportipedia/catalog/equipment/widget/events/widget_created.ex".to_string(),
                    "event widget-created not generated (sparch event widget-created)".to_string(),
                ),
            ]
        );
        assert_eq!(plan.units[4].requires, gate.clone());
        // the use and the moduletag never wait
        assert!(plan.units[0].requires.is_empty());
        assert!(plan.units[1].requires.is_empty());
    }

    #[test]
    fn describe_body_renders_the_create_fold() {
        let ctx = ctx_for("widget");
        let model = &ctx.model;
        let event = model
            .resolve("widget-created", &[ElementKind::Event])
            .expect("fixture event");
        let text = describe_body(&ctx, "Aggregate", &[event]);
        assert!(text.starts_with("describe \"Aggregate\" do\n"));
        assert!(text.contains("  test \"applies widget-created to aggregate state\" do"));
        assert!(text.contains(
            "event = %WidgetCreated{id: UUID.uuid5(:dns, \"equipment:widget:classic-widget\")"
        ));
        assert!(text.contains("result = WidgetAggregate.apply(%WidgetAggregate{}, event)"));
        assert!(text.contains("assert result.title == event.title"));
        // still parses as one describe call
        let file = ElixirFile::parse(&format!("defmodule T do\n{text}\nend\n"));
        assert!(file.parsed(), "{text}");
        assert!(file.has_describe("Aggregate"));
    }

    #[test]
    fn describe_body_renders_the_update_and_delete_and_none_folds() {
        let ctx = ctx_for("widget");
        let event_named = |name: &str| {
            ctx.model
                .resolve(name, &[ElementKind::Event])
                .expect("fixture event")
        };

        let edited = describe_body(&ctx, "Aggregate", &[event_named("widget-edited")]);
        assert!(
            edited
                .contains("result = WidgetAggregate.apply(%WidgetAggregate{id: event.id}, event)")
        );
        assert!(edited.contains("assert result.label == event.label"));

        let archived = describe_body(&ctx, "Aggregate", &[event_named("widget-archived")]);
        assert!(
            archived
                .contains("result = WidgetAggregate.apply(%WidgetAggregate{id: event.id}, event)")
        );
        assert!(archived.contains("assert is_nil(result)"));

        let noted = describe_body(&ctx, "Aggregate", &[event_named("widget-noted")]);
        assert!(noted.contains("state = %WidgetAggregate{id: event.id}"));
        assert!(noted.contains("assert WidgetAggregate.apply(state, event) == state"));
        // the audit fact has no result assertion — nothing materializes
        assert!(!noted.contains("assert result"));
    }

    #[test]
    fn the_describe_check_accepts_the_modelled_spelling() {
        let ctx = ctx_for("widget");
        let plan = &AggregateTest.plans(&ctx)[1];
        let describe = plan
            .units
            .iter()
            .find(|u| matches!(u.id, UnitId::Describe(_)))
            .expect("the describe unit");
        let adopted =
            ElixirFile::parse("defmodule T do\n  describe \"WidgetAggregate\" do\n  end\nend\n");
        assert!((describe.check)(&adopted));
    }
}
