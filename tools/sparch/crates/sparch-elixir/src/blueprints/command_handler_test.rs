//! The command handler's contribution to the operation test file.
//!
//! One `describe "Command Handler"` block exercising `handle/2` with a sample
//! command and asserting the emitted event type. The file, its `use`, its
//! `@moduletag` and its aliases come from
//! [`crate::blueprints::test_case`], the same machinery every contributor of
//! this file uses; the handler's own file and the command's gate the whole
//! contribution.
//!
//! A command that resolves no event plans nothing here: the alias templates
//! name `<Event>`, which stays unresolved, so the run writes no file at all.
//! See the module header of
//! [`crate::blueprints::command_handler`] for the full note.

use sparch_model::ElementKind;

use crate::blueprints::command::Command;
use crate::blueprints::command_handler::CommandHandler;
use crate::blueprints::test_case::{self, Describe, Options};
use crate::context::Context;
use crate::plan::{Blueprint, FilePlan};
use crate::templates;

const TEST_PATH: &str = "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operations/<_operation>_test.exs";
const TEST_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Command>Test";

pub struct CommandHandlerTest;

impl Blueprint for CommandHandlerTest {
    fn name(&self) -> &'static str {
        "command_handler_test"
    }

    /// The sweep asks each blueprint which element kinds it contributes to, so
    /// this test companion names the kind it serves directly.
    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(TEST_PATH, "handle test asserting events")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        // the alias templates below name `<Event>`, which a command that
        // publishes nothing leaves unresolved
        if ctx.events.is_empty() {
            return Vec::new();
        }
        vec![test_case::plan(
            ctx,
            Options {
                path_template: TEST_PATH,
                module_template: TEST_MODULE,
                extra_vars: Default::default(),
                alias_templates: vec![
                    CommandHandler::command_template(),
                    CommandHandler::module_template(),
                    CommandHandler::event_template(),
                    CommandHandler::aggregate_template(),
                ],
                alias_modules: Vec::new(),
                requires: vec![
                    (
                        CommandHandler::module_file(ctx),
                        "handler not generated (sparch command_handler)".to_string(),
                    ),
                    (
                        Command::module_file(ctx),
                        "command not generated (sparch command)".to_string(),
                    ),
                ],
                alias_requires: None,
                describes: vec![Describe {
                    subject_template: "Command Handler",
                    body: Box::new(describe_body),
                    alternates: vec!["<Command>Handler"],
                }],
            },
        )]
    }
}

/// The command handler's describe body, heredoc whitespace included. The
/// sample command is every field of the model with its sample value, the
/// handler is called on an empty aggregate, and the assertion names the event
/// the command publishes.
pub fn describe_body(ctx: &Context, subject: &str) -> String {
    let command = ctx.render_or_panic("<Command>");
    let handler = command.clone() + "Handler";
    let event = CommandHandler::event_render(ctx);
    let aggregate = ctx.render_or_panic("<DomainObject>Aggregate");
    let body = templates::struct_body(ctx);

    format!(
        "describe \"{subject}\" do\n  test \"handles {command} command and returns {event} event\" do\n    cmd = %{command}{{{body}}}\n\n    events = {handler}.handle(%{aggregate}{{}}, cmd)\n\n    assert %{event}{{}} = events\n  end\nend"
    )
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
            .resolve(name, &[ElementKind::Command])
            .expect("fixture command");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn plan(name: &str) -> FilePlan {
        CommandHandlerTest.plans(&ctx_for(name)).remove(0)
    }

    #[test]
    fn the_test_file_lands_the_handlers_four_aliases_and_its_describe() {
        let plan = plan("create-widget");
        assert_eq!(
            plan.path,
            "services/api/test/sportipedia/catalog/equipment/widget/operations/create_widget_test.exs"
        );
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.Catalog.Equipment.Widget.Operation.CreateWidgetTest")
        );
        assert!(plan.requires_describe);
        let ids: Vec<String> = plan.units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            ids,
            vec![
                "use Sportipedia.CatalogTestCase",
                "moduletag",
                "test_alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget",
                "test_alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidgetHandler",
                "test_alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated",
                "test_alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate",
                "describe Command Handler",
            ]
        );
    }

    #[test]
    fn every_contribution_waits_for_the_handler_and_the_command() {
        let plan = plan("create-widget");
        let gates = vec![
            (
                "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/handler.ex"
                    .to_string(),
                "handler not generated (sparch command_handler)".to_string(),
            ),
            (
                "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/command.ex"
                    .to_string(),
                "command not generated (sparch command)".to_string(),
            ),
        ];
        for unit in &plan.units[2..] {
            assert_eq!(unit.requires, gates, "{}", unit.id.label());
        }
        // the file's own use and moduletag never wait
        assert!(plan.units[0].requires.is_empty());
        assert!(plan.units[1].requires.is_empty());
    }

    #[test]
    fn the_event_alias_names_the_first_published_event() {
        // relabel-widget publishes two facts and the test asserts one, the
        // same event `handle/2`'s spec promises
        let ids: Vec<String> = plan("relabel-widget")
            .units
            .iter()
            .filter(|u| matches!(u.id, UnitId::TestAlias(_)))
            .map(|u| u.id.label())
            .collect();
        assert_eq!(ids.len(), 4, "{ids:?}");
        assert!(ids[2].ends_with("Event.WidgetRelabelled"), "{ids:?}");
        let body = describe_body(&ctx_for("relabel-widget"), "Command Handler");
        assert!(body.contains("returns WidgetRelabelled event"), "{body}");
        assert!(body.contains("assert %WidgetRelabelled{} = events"));
    }

    #[test]
    fn the_describe_body_is_the_expected_heredoc() {
        let ctx = ctx_for("archive-widget");
        assert_eq!(
            describe_body(&ctx, "Command Handler"),
            "describe \"Command Handler\" do\n  test \"handles ArchiveWidget command and returns WidgetArchived event\" do\n    cmd = %ArchiveWidget{id: UUID.uuid5(:dns, \"equipment:widget:classic-widget\")}\n\n    events = ArchiveWidgetHandler.handle(%WidgetAggregate{}, cmd)\n\n    assert %WidgetArchived{} = events\n  end\nend"
        );
    }

    #[test]
    fn the_describe_check_accepts_the_alternate_spelling() {
        let units = plan("create-widget").units;
        let describe = units
            .iter()
            .find(|u| u.id.label() == "describe Command Handler")
            .expect("the describe");
        let hand_written = ElixirFile::parse(
            "defmodule T do\n  describe \"CreateWidgetHandler\" do\n  end\nend\n",
        );
        assert!((describe.check)(&hand_written));
        let other = ElixirFile::parse("defmodule T do\n  describe \"Command\" do\n  end\nend\n");
        assert!(!(describe.check)(&other));
    }

    #[test]
    fn a_command_that_publishes_nothing_plans_nothing() {
        // the alias templates would name an unresolved `<Event>`, which is
        // why this plans no file at all rather than a half-filled one
        let ctx = ctx_for("catalog-apparatus");
        assert!(ctx.events.is_empty(), "the model holds no such event");
        assert!(CommandHandlerTest.plans(&ctx).is_empty());
    }
}
