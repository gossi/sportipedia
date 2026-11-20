//! The event's own test file.
//!
//! A `describe "Event"` block exercising construction, enforced fields, and
//! JSON serialization. The event, not the operation, is what is tested
//! here — the fact is the unit of behaviour, so the aggregate's
//! `describe "Aggregate"` and the projector's `describe "Projector"` for
//! the same event join this file through the same `TestCaseFile` machinery.

use crate::blueprints::event::Event;
use crate::blueprints::test_case::{self, Describe, Options};
use crate::context::Context;
use crate::plan::{Blueprint, FilePlan};
use crate::templates;

const TEST_PATH: &str = "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/events/<_event>_test.exs";
const TEST_MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>Test";

pub struct EventTest;

impl Blueprint for EventTest {
    fn name(&self) -> &'static str {
        "event_test"
    }

    /// The sweep asks each module for its participation, so the
    /// companion names the kind it contributes to.
    fn source_kinds(&self) -> Vec<sparch_model::ElementKind> {
        vec![sparch_model::ElementKind::Event]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(TEST_PATH, "construction and serialization tests")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        vec![test_case::plan(
            ctx,
            Options {
                path_template: TEST_PATH,
                module_template: TEST_MODULE,
                extra_vars: Default::default(),
                alias_templates: vec![Event::module_template()],
                alias_modules: Vec::new(),
                requires: vec![(
                    Event::module_file(ctx),
                    "event not generated (sparch event)".to_string(),
                )],
                alias_requires: None,
                describes: vec![Describe {
                    subject_template: "Event",
                    body: Box::new(describe_body),
                    alternates: vec!["<Event> event"],
                }],
            },
        )]
    }
}

/// The `describe` body, heredoc whitespace
/// included.
pub fn describe_body(ctx: &Context, subject: &str) -> String {
    let event = ctx.render_or_panic("<Event>");
    let body = templates::struct_body(ctx);

    let tests = [
        format!(
            "test \"creates {event} with required fields\" do\n  event = struct!({event}, %{{{body}}})\n\n  assert event.id != nil\nend"
        ),
        format!(
            "test \"requires enforced fields\" do\n  assert_raise ArgumentError, fn ->\n    struct!({event}, %{{}})\n  end\nend"
        ),
        format!(
            "test \"serializes to JSON\" do\n  event = struct!({event}, %{{{body}}})\n\n  assert {{:ok, _json}} = Jason.encode(event)\nend"
        ),
    ];

    let joined = tests.join("\n\n");
    format!(
        "describe \"{subject}\" do\n{}\nend",
        templates::indent(&joined, 2)
    )
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
            .resolve(event, &[sparch_model::ElementKind::Event])
            .expect("fixture event");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    #[test]
    fn the_test_plan_carries_the_shared_shape() {
        let ctx = ctx_for("widget-created");
        let plan = &EventTest.plans(&ctx)[0];
        assert_eq!(
            plan.path,
            "services/api/test/sportipedia/catalog/equipment/widget/events/widget_created_test.exs"
        );
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreatedTest")
        );
        assert!(plan.requires_describe);
        assert!(plan.unit_created);
        let ids: Vec<String> = plan.units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            ids,
            vec![
                "use Sportipedia.CatalogTestCase",
                "moduletag",
                "test_alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated",
                "describe Event",
            ]
        );
        // the gate: the event module must exist before the alias and the
        // describe land
        let gate = "services/api/lib/sportipedia/catalog/equipment/widget/events/widget_created.ex";
        assert_eq!(plan.units[2].requires[0].0, gate);
        assert_eq!(
            plan.units[2].requires[0].1,
            "event not generated (sparch event)"
        );
        assert_eq!(plan.units[3].requires[0].0, gate);
    }

    #[test]
    fn describe_body_renders_the_three_cases() {
        let ctx = ctx_for("widget-created");
        let text = describe_body(&ctx, "Event");
        assert!(text.starts_with("describe \"Event\" do\n"));
        assert!(text.ends_with("\nend"));
        assert!(text.contains("  test \"creates WidgetCreated with required fields\" do"));
        assert!(text.contains(
            "    event = struct!(WidgetCreated, %{id: UUID.uuid5(:dns, \"equipment:widget:classic-widget\"), title: \"Classic Widget\""
        ));
        assert!(text.contains("    assert_raise ArgumentError, fn ->"));
        assert!(text.contains("    assert {:ok, _json} = Jason.encode(event)"));
        // the wrapped text still parses as one describe call
        let file = ElixirFile::parse(&format!("defmodule T do\n{text}\nend\n"));
        assert!(file.parsed(), "{text}");
        assert!(file.has_describe("Event"));
    }

    #[test]
    fn describe_check_accepts_the_modelled_spelling() {
        let ctx = ctx_for("widget-created");
        let plan = &EventTest.plans(&ctx)[0];
        let describe = &plan.units[3];
        let adopted = ElixirFile::parse(
            "defmodule T do\n  describe \"WidgetCreated event\" do\n  end\nend\n",
        );
        assert!((describe.check)(&adopted));
    }
}
