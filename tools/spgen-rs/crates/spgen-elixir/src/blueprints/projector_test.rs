use spgen_model::{Element, ElementKind};

use crate::blueprints::event::Event;
use crate::blueprints::projector::Projector;
use crate::blueprints::read_model::ReadModel;
use crate::blueprints::test_case::{self, Describe, Options};
use crate::context::{Befield, Context, Operation};
use crate::plan::{Blueprint, FilePlan};
use crate::templates;

const TEST_PATH: &str = "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/events/<_event>_test.exs";
const TEST_MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>Test";

pub struct ProjectorTest;

impl Blueprint for ProjectorTest {
    fn name(&self) -> &'static str {
        "projector_test"
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Event]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(TEST_PATH, "projected row test per fact")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        match ctx.effect_for_event(&ctx.element.name) {
            None => Vec::new(),
            Some(Operation::None) => Vec::new(),
            _ => vec![projector_plan(ctx)],
        }
    }
}

fn projector_plan(ctx: &Context) -> FilePlan {
    test_case::plan(
        ctx,
        Options {
            path_template: TEST_PATH,
            module_template: TEST_MODULE,
            extra_vars: Default::default(),
            alias_templates: vec![Projector::module_template(), ReadModel::module_template()],
            alias_modules: seed_modules(ctx),
            requires: vec![
                (
                    Projector::module_file(ctx),
                    "projector not generated (spgen projector)".to_string(),
                ),
                (
                    Event::module_file(ctx),
                    "event not generated (spgen event)".to_string(),
                ),
                (
                    ReadModel::module_file(ctx),
                    "read model not generated (spgen read_model)".to_string(),
                ),
            ],
            alias_requires: None,
            describes: vec![Describe {
                subject_template: "Projector",
                body: Box::new(describe_body),
                alternates: vec![
                    "<DomainObject>Projector - <Event>",
                    "<DomainObject>Projector",
                ],
            }],
        },
    )
}

fn seed_modules(ctx: &Context) -> Vec<String> {
    match ctx.effect_for_event(&ctx.element.name) {
        Some(Operation::Create) => Vec::new(),
        _ => match create_event(ctx) {
            None => Vec::new(),
            Some(e) => vec![
                ctx.with_element(&e)
                    .render_or_panic(Event::module_template()),
            ],
        },
    }
}

fn create_event(ctx: &Context) -> Option<Element> {
    ctx.model
        .events_of(&ctx.constituent)
        .into_iter()
        .find(|e| ctx.effect_for_event(&e.name) == Some(Operation::Create))
}

pub fn describe_body(ctx: &Context, subject: &str) -> String {
    let projector = ctx.render_or_panic("<DomainObject>Projector");
    let event_pascal = Context::pascal(&ctx.element.name);
    let read_model = format!("{}ReadModel", Context::pascal(&ctx.constituent));
    match ctx.effect_for_event(&ctx.element.name) {
        Some(Operation::Create) => {
            let body = templates::struct_body(ctx);
            block(
                subject,
                &projector,
                &event_pascal,
                &read_model,
                &body,
                None,
                ctx,
                "!= nil",
            )
        }
        effect => match create_seed(ctx) {
            Some(seed) => {
                let body = templates::struct_body_with(ctx, &[("id", "create_event.id")]);
                let outcome = outcome(effect);
                block(
                    subject,
                    &projector,
                    &event_pascal,
                    &read_model,
                    &body,
                    Some(&seed),
                    ctx,
                    &outcome,
                )
            }
            None => {
                let body = templates::struct_body(ctx);
                block(
                    subject,
                    &projector,
                    &event_pascal,
                    &read_model,
                    &body,
                    None,
                    ctx,
                    "!= nil",
                )
            }
        },
    }
}

fn outcome(effect: Option<Operation>) -> String {
    match effect {
        Some(Operation::Delete) => "== nil".to_string(),
        _ => "!= nil".to_string(),
    }
}

fn create_seed(ctx: &Context) -> Option<String> {
    let e = create_event(ctx)?;
    let pascal = Context::pascal(&e.name);
    let fields: Vec<Befield> = spgen_model::fields(&e)
        .iter()
        .map(Befield::from_field)
        .collect();
    let literal = fields
        .iter()
        .map(|f| format!("{}: {}", f.name, templates::sample_value(ctx, f)))
        .collect::<Vec<_>>()
        .join(", ");
    let projector = ctx.render_or_panic("<DomainObject>Projector");
    Some(format!(
        "create_event = %{pascal}{{{literal}}}\n\n{}assert :ok = {projector}.handle(create_event, create_metadata)\n",
        metadata(ctx, "create_metadata", "create_event", 1)
    ))
}

fn metadata(ctx: &Context, var: &str, event_var: &str, number: usize) -> String {
    let projection = Projector::projection_name(ctx);
    let app = Context::pascal(&ctx.subdomain);
    format!(
        "{var} = %{{\n  handler_name: \"{projection}\",\n  event_number: {number},\n  event_id: UUID.uuid4(),\n  stream_id: \"{}-#{{{}.id}}\",\n  stream_version: {number},\n  correlation_id: nil,\n  causation_id: nil,\n  created_at: DateTime.utc_now(),\n  application: Sportipedia.{app},\n  state: nil\n}}\n",
        ctx.constituent, event_var
    )
}

#[allow(clippy::too_many_arguments)]
fn block(
    subject: &str,
    projector: &str,
    event_pascal: &str,
    read_model: &str,
    body: &str,
    seed: Option<&String>,
    ctx: &Context,
    outcome: &str,
) -> String {
    let number = if seed.is_some() { 2 } else { 1 };
    let head = match seed {
        Some(seed) => format!("{seed}\n"),
        None => String::new(),
    };
    let event_part = format!(
        "{head}event = %{event_pascal}{{{body}}}\n\n{}",
        metadata(ctx, "metadata", "event", number)
    );
    let parts = [
        event_part,
        format!("assert :ok = {projector}.handle(event, metadata)"),
        String::new(),
        format!("assert Repo.get({read_model}, event.id) {outcome}"),
    ];
    let joined = parts.join("\n");
    format!(
        "describe \"{subject}\" do\n  test \"projects {event_pascal} to the {} read model\" do\n{}\n  end\nend",
        ctx.constituent,
        templates::indent(&joined, 4)
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use crate::elixir::ElixirFile;
    use crate::plan::UnitId;
    use spgen_model::Model;
    use std::path::PathBuf;

    fn ctx_for(event: &str) -> Context {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model
            .resolve(event, &[ElementKind::Event])
            .expect("fixture event");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    #[test]
    fn an_undeclared_or_none_event_contributes_nothing() {
        assert!(ProjectorTest.plans(&ctx_for("widget-noted")).is_empty());
        assert!(
            ProjectorTest
                .plans(&ctx_for("widget-rename-logged"))
                .is_empty()
        );
    }

    #[test]
    fn the_create_contribution_lands_projector_and_read_model_aliases() {
        let plan = &ProjectorTest.plans(&ctx_for("widget-created"))[0];
        assert_eq!(
            plan.path,
            "services/api/test/sportipedia/catalog/equipment/widget/events/widget_created_test.exs"
        );
        let ids: Vec<String> = plan.units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            ids,
            vec![
                "use Sportipedia.CatalogTestCase",
                "moduletag",
                "test_alias Sportipedia.Catalog.Equipment.Widget.WidgetProjector",
                "test_alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel",
                "describe Projector",
            ]
        );
    }

    #[test]
    fn an_update_contribution_aliases_the_seed_create_event_too() {
        let plan = &ProjectorTest.plans(&ctx_for("widget-edited"))[0];
        let ids: Vec<String> = plan.units.iter().map(|u| u.id.label()).collect();
        assert!(
            ids.iter()
                .any(|id| id
                    == "test_alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated"),
            "the seeded create fact needs its module: {ids:?}"
        );
    }

    #[test]
    fn every_contribution_waits_for_the_three_citizens() {
        let plan = &ProjectorTest.plans(&ctx_for("widget-created"))[0];
        let gates: Vec<&str> = plan.units[4]
            .requires
            .iter()
            .map(|(_, reason)| reason.as_str())
            .collect();
        assert_eq!(
            gates,
            vec![
                "projector not generated (spgen projector)",
                "event not generated (spgen event)",
                "read model not generated (spgen read_model)"
            ]
        );
    }

    #[test]
    fn the_create_describe_projections_the_row() {
        let ctx = ctx_for("widget-created");
        let text = describe_body(&ctx, "Projector");
        assert!(text.starts_with("describe \"Projector\" do\n"));
        assert!(text.contains("test \"projects WidgetCreated to the widget read model\" do"));
        assert!(text.contains("handler_name: \"equipment.widget_projection\""));
        assert!(text.contains("stream_id: \"widget-#{event.id}\""));
        assert!(text.contains("application: Sportipedia.Catalog"));
        assert!(text.contains("assert :ok = WidgetProjector.handle(event, metadata)"));
        assert!(text.contains("assert Repo.get(WidgetReadModel, event.id) != nil"));
        let file = ElixirFile::parse(&format!("defmodule T do\n{text}\nend\n"));
        assert!(file.parsed(), "{text}");
        assert!(file.has_describe("Projector"));
    }

    #[test]
    fn the_update_describe_seeds_a_create_event_first() {
        let ctx = ctx_for("widget-edited");
        let text = describe_body(&ctx, "Projector");
        assert!(text.contains("create_event = %WidgetCreated{"));
        assert!(
            text.contains("assert :ok = WidgetProjector.handle(create_event, create_metadata)")
        );
        assert!(text.contains("id: create_event.id"));
        assert!(text.contains("event_number: 1"));
        assert!(text.contains("event_number: 2"));
        assert!(text.contains("stream_id: \"widget-#{create_event.id}\""));
    }

    #[test]
    fn the_delete_describe_asserts_a_removed_row() {
        let ctx = ctx_for("widget-archived");
        let text = describe_body(&ctx, "Projector");
        assert!(text.contains("assert Repo.get(WidgetReadModel, event.id) == nil"));
    }

    #[test]
    fn the_describe_check_accepts_the_moduleled_spelling() {
        let plan = &ProjectorTest.plans(&ctx_for("widget-created"))[0];
        let describe = plan
            .units
            .iter()
            .find(|u| matches!(u.id, UnitId::Describe(_)))
            .expect("the describe unit");
        let adopted = ElixirFile::parse(
            "defmodule T do\n  describe \"WidgetProjector - WidgetCreated\" do\n  end\nend\n",
        );
        assert!((describe.check)(&adopted));
        let plain =
            ElixirFile::parse("defmodule T do\n  describe \"WidgetProjector\" do\n  end\nend\n");
        assert!((describe.check)(&plain));
    }
}
