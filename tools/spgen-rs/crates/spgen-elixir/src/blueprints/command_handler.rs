//! The commanded command handler file — the executable transfer of
//! `docs/architecture/blueprints/backend/domain/command-handler.md`, ported
//! from `SpGen.Blueprint.CommandHandler`
//! (`tools/spgen/lib/sp_gen/blueprint/command_handler.ex`).
//!
//! One `handle/2` for one command: the `@behaviour Commanded.Commands.Handler`,
//! the aliases for aggregate, command and every published event, the `@doc`,
//! the `@spec` (`event.t() | [event.t()]`) and the head matching
//! `%Aggregate{}` and `%Command{}`. The body stays the blueprint's two comment
//! lines. What the command turns into which fact is the operator's, decided by
//! the feature spec.
//!
//! Fixed shape: the handler looks the same for every operation (input command,
//! output events), only the event names differ, so there is no `--template`.
//!
//! The command's registration in the commanded router (`dispatch … to:`) is
//! contributed by [`crate::blueprints::command_router`], not here.
//!
//! ## Deliberate divergence: a command that publishes nothing
//!
//! `event_render/1` keeps the oracle's `"Event"` answer when no event
//! resolves, but [`CommandHandler::plans`] plans **nothing** for such a
//! command. The oracle's own run reaches no file either: its generator plans
//! this module and [`crate::blueprints::command_handler_test`] in one pass, the
//! companion renders `<Event>` from the same empty list, `SpGen.Context`
//! raises on the unresolved placeholder, and a direct run dies before
//! `SpGen.apply_plans/2` has written a byte. Reached from another run's
//! neighborhood sweep it dies mid-sweep, and the handler generator still
//! writes nothing. Planning nothing keeps this wave's file output identical to
//! the oracle's pre-crash output while the run finishes and reports, so the
//! port never dies where the oracle dies. Parity drives only the shapes the
//! oracle can generate; `command_handler_parity_with_the_elixir_oracle` states
//! the crash itself.

use spgen_model::{Element, ElementKind};

use crate::blueprints::aggregate::Aggregate;
use crate::blueprints::command::Command;
use crate::blueprints::event::Event;
use crate::context::Context;
use crate::elixir::Rank;
use crate::plan::{Blueprint, FilePlan, Placement, Unit, UnitId};

const PATH: &str = "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/operations/<_operation>/handler.ex";
const MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>Handler";
const AGGREGATE_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate";
const COMMAND_MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>";
const EVENT_MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>";

pub struct CommandHandler;

impl CommandHandler {
    /// The handler module's file path (used as a `requires` gate) —
    /// `CommandHandler.module_file/1`.
    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(PATH)
    }

    /// The handler's module-name template (`CommandHandlerTest` aliases it) —
    /// `CommandHandler.module_template/0`.
    pub fn module_template() -> &'static str {
        MODULE
    }

    /// `CommandHandler.command_template/0`.
    pub fn command_template() -> &'static str {
        COMMAND_MODULE
    }

    /// `CommandHandler.aggregate_template/0`.
    pub fn aggregate_template() -> &'static str {
        AGGREGATE_MODULE
    }

    /// `CommandHandler.event_template/0`.
    pub fn event_template() -> &'static str {
        EVENT_MODULE
    }

    /// Pascal-cased first event name of the command, e.g. `ApparatusCataloged`
    /// — `CommandHandler.event_render/1`. The oracle's `"Event"` answer for an
    /// empty list is unreachable from a plan (see the module header): a
    /// command that resolves no event plans nothing.
    pub fn event_render(ctx: &Context) -> String {
        match ctx.events.first() {
            Some(ev) => Context::pascal(&ev.name),
            None => "Event".to_string(),
        }
    }
}

impl Blueprint for CommandHandler {
    fn name(&self) -> &'static str {
        "command_handler"
    }

    fn description(&self) -> Option<&'static str> {
        Some("Generates a command handler module and its test describe block")
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(PATH, "handle/2 calling the aggregate")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        if ctx.events.is_empty() {
            return Vec::new();
        }
        vec![FilePlan::new(
            ctx.render_or_panic(PATH),
            Some(ctx.render_or_panic(MODULE)),
            units(ctx),
        )]
    }
}

// ------------------------------------------------------------------- units

/// `CommandHandler.units/1` — behaviour and aliases first, then the clause.
fn units(ctx: &Context) -> Vec<Unit> {
    let mut units = behaviour_units(ctx);
    units.extend(alias_units(ctx));
    units.extend(handle_units(ctx));
    units
}

/// `CommandHandler.behaviour_unit/0` — the doc names the command, so the
/// moduledoc unit takes the context.
fn behaviour_units(ctx: &Context) -> Vec<Unit> {
    let doc = format!(
        "@moduledoc \"\"\"\nHandles the {} command.\n\"\"\"",
        ctx.render_or_panic("<Command>")
    );
    vec![
        Unit {
            id: UnitId::ModuledocFor("handler".into()),
            check: Box::new(|f| f.has_moduledoc()),
            render: Box::new(move || doc.clone()),
            place: Placement::Head {
                rank: Rank::Moduledoc,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        },
        Unit {
            id: UnitId::Behaviour("Commanded.Commands.Handler".into()),
            check: Box::new(|f| f.attr_names("behaviour", "Commanded.Commands.Handler")),
            render: Box::new(|| "@behaviour Commanded.Commands.Handler".to_string()),
            place: Placement::Head {
                rank: Rank::Attribute,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        },
    ]
}

/// The aliases the handler's own code names, each waiting for the citizen it
/// points at — `CommandHandler.alias_units/1`. The oracle keys these units
/// `{:router_alias, module}`, and the port keeps that id.
fn alias_units(ctx: &Context) -> Vec<Unit> {
    let mut units = vec![
        alias_unit(&ctx.render_or_panic(AGGREGATE_MODULE), aggregate_gate(ctx)),
        alias_unit(&ctx.render_or_panic(COMMAND_MODULE), command_gate(ctx)),
    ];
    units.extend(ctx.events.iter().map(|ev| {
        let ev_ctx = ctx.with_element(ev);
        alias_unit(
            &ev_ctx.render_or_panic(EVENT_MODULE),
            event_gate(ev, &Event::module_file(&ev_ctx)),
        )
    }));
    units
}

fn alias_unit(full: &str, requires: Vec<(String, String)>) -> Unit {
    let check_module = full.to_string();
    let render = format!("alias {full}");
    Unit {
        id: UnitId::RouterAlias(full.to_string()),
        check: Box::new(move |f| f.has_alias(&check_module)),
        render: Box::new(move || render.clone()),
        requires,
        place: Placement::Head {
            rank: Rank::Alias,
            alias_sort_key: Some(full.to_string()),
        },
        stale: None,
    }
}

/// `CommandHandler.handle_units/1` — the clause whose text comes from the
/// plan's context: the command, its aggregate and the first event it publishes.
fn handle_units(ctx: &Context) -> Vec<Unit> {
    let event = CommandHandler::event_render(ctx);
    let aggregate = ctx.render_or_panic("<DomainObject>Aggregate");
    let command = ctx.render_or_panic("<Command>");
    let render = format!(
        "@doc \"\"\"\nHandles the {command} command and returns {event} event(s).\n\"\"\"\n@spec handle({aggregate}.t(), {command}.t()) :: {event}.t() | [{event}.t()]\ndef handle(%{aggregate}{{}} = aggregate, %{command}{{}} = cmd) do\n  # implement logic here\n  # return events\nend"
    );
    let mut requires = command_gate(ctx);
    requires.extend(aggregate_gate(ctx));
    vec![Unit {
        id: UnitId::Def("handle".into(), 2),
        check: Box::new(|f| f.has_def("handle", 2)),
        render: Box::new(move || render.clone()),
        requires,
        place: Placement::BodyEnd,
        stale: None,
    }]
}

/// The handler's `requires` gates. A named citizen must exist before the unit
/// that names it may land.
fn aggregate_gate(ctx: &Context) -> Vec<(String, String)> {
    vec![(
        Aggregate::module_file(ctx),
        "aggregate not generated (spgen aggregate)".to_string(),
    )]
}

fn command_gate(ctx: &Context) -> Vec<(String, String)> {
    vec![(
        Command::module_file(ctx),
        "command not generated (spgen command)".to_string(),
    )]
}

fn event_gate(event: &Element, path: &str) -> Vec<(String, String)> {
    vec![(
        path.to_string(),
        format!(
            "event {} not generated (spgen event {})",
            event.name, event.name
        ),
    )]
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use spgen_model::Model;
    use std::path::PathBuf;

    fn model() -> Model {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        Model::load(&root.canonicalize().expect("fixture corpus"))
    }

    fn ctx_for(name: &str) -> Context {
        let model = model();
        let element = model
            .resolve(name, &[ElementKind::Command])
            .expect("fixture command");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn units_for(name: &str) -> Vec<Unit> {
        CommandHandler.plans(&ctx_for(name)).remove(0).units
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
            CommandHandler::module_file(&ctx),
            "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/handler.ex"
        );
        let plan = &CommandHandler.plans(&ctx)[0];
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.Catalog.Equipment.Widget.Command.CreateWidgetHandler")
        );
        assert!(plan.unit_created, "the handler is created by its units");
    }

    #[test]
    fn unit_ids_and_order_mirror_the_oracle() {
        let units = units_for("relabel-widget");
        let labels: Vec<String> = units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            labels,
            vec![
                "moduledoc handler",
                "behaviour Commanded.Commands.Handler",
                "router_alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate",
                "router_alias Sportipedia.Catalog.Equipment.Widget.Command.RelabelWidget",
                "router_alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetRelabelled",
                "router_alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetRenameLogged",
                "handle/2",
            ]
        );
    }

    #[test]
    fn the_event_aliases_follow_the_publishes_order() {
        // relabel-widget publishes widget-relabelled and
        // widget-rename-logged; create-widget publishes one fact
        let two: Vec<String> = units_for("relabel-widget")
            .iter()
            .filter(|u| matches!(u.id, UnitId::RouterAlias(_)))
            .map(|u| u.id.label())
            .collect();
        assert_eq!(two.len(), 4, "aggregate, command, both events: {two:?}");
        assert!(two[2].ends_with("Event.WidgetRelabelled"), "{two:?}");
        assert!(two[3].ends_with("Event.WidgetRenameLogged"), "{two:?}");
        let one: Vec<String> = units_for("create-widget")
            .iter()
            .filter(|u| matches!(u.id, UnitId::RouterAlias(_)))
            .map(|u| u.id.label())
            .collect();
        assert_eq!(one.len(), 3, "aggregate, command, one event: {one:?}");
    }

    #[test]
    fn event_render_is_the_pascal_first_published_event() {
        assert_eq!(
            CommandHandler::event_render(&ctx_for("create-widget")),
            "WidgetCreated"
        );
        assert_eq!(
            CommandHandler::event_render(&ctx_for("relabel-widget")),
            "WidgetRelabelled"
        );
        // the oracle's answer for a command that resolves no event, kept for
        // the shapes the oracle reaches (see the module header)
        let mut bare = ctx_for("catalog-apparatus");
        bare.events.clear();
        assert_eq!(CommandHandler::event_render(&bare), "Event");
    }

    #[test]
    fn renders_carry_the_exact_oracle_text() {
        let units = units_for("create-widget");
        assert_eq!(
            render(&units, "moduledoc handler"),
            "@moduledoc \"\"\"\nHandles the CreateWidget command.\n\"\"\""
        );
        assert_eq!(
            render(&units, "behaviour Commanded.Commands.Handler"),
            "@behaviour Commanded.Commands.Handler"
        );
        assert_eq!(
            render(
                &units,
                "router_alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate"
            ),
            "alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate"
        );
        assert_eq!(
            render(&units, "handle/2"),
            "@doc \"\"\"\nHandles the CreateWidget command and returns WidgetCreated event(s).\n\"\"\"\n@spec handle(WidgetAggregate.t(), CreateWidget.t()) :: WidgetCreated.t() | [WidgetCreated.t()]\ndef handle(%WidgetAggregate{} = aggregate, %CreateWidget{} = cmd) do\n  # implement logic here\n  # return events\nend"
        );
    }

    #[test]
    fn each_alias_waits_for_the_citizen_it_names() {
        let units = units_for("create-widget");
        assert_eq!(
            unit(
                &units,
                "router_alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate"
            )
            .requires,
            vec![(
                "services/api/lib/sportipedia/catalog/equipment/widget/aggregate.ex".to_string(),
                "aggregate not generated (spgen aggregate)".to_string(),
            )]
        );
        assert_eq!(
            unit(
                &units,
                "router_alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget"
            )
            .requires,
            vec![(
                "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/command.ex"
                    .to_string(),
                "command not generated (spgen command)".to_string(),
            )]
        );
        assert_eq!(
            unit(
                &units,
                "router_alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated"
            )
            .requires,
            vec![(
                "services/api/lib/sportipedia/catalog/equipment/widget/events/widget_created.ex"
                    .to_string(),
                "event widget-created not generated (spgen event widget-created)".to_string(),
            )]
        );
    }

    #[test]
    fn the_clause_waits_for_command_and_aggregate_in_that_order() {
        let units = units_for("create-widget");
        let handle = unit(&units, "handle/2");
        let gates: Vec<&str> = handle
            .requires
            .iter()
            .map(|(_, reason)| reason.as_str())
            .collect();
        assert_eq!(
            gates,
            vec![
                "command not generated (spgen command)",
                "aggregate not generated (spgen aggregate)"
            ]
        );
        assert!(matches!(handle.place, Placement::BodyEnd));
        // the doc and the behaviour name no citizen, so nothing gates them
        assert!(unit(&units, "moduledoc handler").requires.is_empty());
        assert!(
            unit(&units, "behaviour Commanded.Commands.Handler")
                .requires
                .is_empty()
        );
    }

    #[test]
    fn a_command_that_publishes_nothing_plans_nothing() {
        // the oracle dies here instead: its companion test blueprint renders
        // `<Event>` from the same empty list and the run raises before any
        // file is written. The port says the same with its files: nothing.
        let ctx = ctx_for("catalog-apparatus");
        assert!(ctx.events.is_empty(), "the model holds no such event");
        assert!(CommandHandler.plans(&ctx).is_empty());
    }

    #[test]
    fn the_finished_handler_file_reads_fully_present() {
        // what the oracle creates, parsed back: every unit reads present
        let text = "defmodule Sportipedia.Catalog.Equipment.Widget.Command.CreateWidgetHandler do\n  @moduledoc \"\"\"\n  Handles the CreateWidget command.\n  \"\"\"\n  alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget\n  alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated\n  alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate\n  @behaviour Commanded.Commands.Handler\n  @doc \"\"\"\n  Handles the CreateWidget command and returns WidgetCreated event(s).\n  \"\"\"\n  @spec handle(WidgetAggregate.t(), CreateWidget.t()) ::\n          WidgetCreated.t() | [WidgetCreated.t()]\n  def handle(%WidgetAggregate{} = aggregate, %CreateWidget{} = cmd) do\n    # implement logic here\n    # return events\n  end\nend\n";
        let file = crate::elixir::ElixirFile::parse(text);
        for unit in &units_for("create-widget") {
            assert!((unit.check)(&file), "{} must read present", unit.id.label());
        }
    }
}
