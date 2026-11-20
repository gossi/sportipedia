//! The composite's commanded router registration — ported from
//! `SpGen.Blueprint.CommandRouter`
//! (`tools/spgen/lib/sp_gen/blueprint/command_router.ex`), the registration
//! half of `docs/architecture/blueprints/backend/domain/command.md`.
//!
//! Aliases for command, handler and aggregate, the `identify` entry (once
//! per aggregate) and the `dispatch` entry grouping the command with its
//! handler.
//!
//! The router is a registration file, but a composite is not allowed to
//! lack one: the plan is unit-created, so when the file is missing the run
//! applies its units (`use Commanded.Commands.Router` and the two
//! middlewares) to a fresh module shell and `sparch command` never fails on
//! the composite's first command.

use sparch_model::ElementKind;

use crate::blueprints::aggregate::Aggregate;
use crate::blueprints::command::Command;
use crate::blueprints::command_handler::CommandHandler;
use crate::context::Context;
use crate::elixir::Rank;
use crate::plan::{Blueprint, FilePlan, MacroPredicate, Placement, Unit, UnitId};

const ROUTER_PATH: &str = "services/api/lib/sportipedia/<_subdomain>/<composite>/router.ex";
const ROUTER_MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.Router";
const AGGREGATE_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate";
const MIDDLEWARES: [&str; 2] = ["Identity", "Validate"];

pub struct CommandRouter;

impl CommandRouter {
    /// The composite router's path — the gate for app and router
    /// registrations. `CommandRouter.module_file/1`.
    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(ROUTER_PATH)
    }
}

impl Blueprint for CommandRouter {
    fn name(&self) -> &'static str {
        "command_router"
    }

    /// The oracle derives this blueprint's sweep participation from the
    /// generator's head; the Rust sweep asks each ported module, so the
    /// registration host names the kind it registers.
    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(ROUTER_PATH, "dispatch and middleware registration")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        let command = ctx.render_or_panic("<Command>");
        let handler = command.clone() + "Handler";
        let aggregate = ctx.render_or_panic("<DomainObject>Aggregate");

        let mut units = vec![use_unit()];
        for name in MIDDLEWARES {
            units.extend(middleware_units(name));
        }
        units.push(registration_alias(
            &ctx.render_or_panic(Command::module_template()),
            command_gate(ctx),
        ));
        units.push(registration_alias(
            &(ctx.render_or_panic(Command::module_template()) + "Handler"),
            handler_gate(ctx),
        ));
        units.push(registration_alias(
            &ctx.render_or_panic(AGGREGATE_MODULE),
            aggregate_gate(ctx),
        ));
        units.push(identify_unit(ctx, &aggregate, aggregate_gate(ctx)));
        let mut dispatch_gates = command_gate(ctx);
        dispatch_gates.extend(handler_gate(ctx));
        dispatch_gates.extend(aggregate_gate(ctx));
        units.push(dispatch_unit(
            &command,
            &handler,
            &aggregate,
            dispatch_gates,
        ));

        vec![FilePlan::new(
            Self::module_file(ctx),
            Some(ctx.render_or_panic(ROUTER_MODULE)),
            units,
        )]
    }
}

fn use_unit() -> Unit {
    Unit {
        id: UnitId::Use("Commanded.Commands.Router".into()),
        check: Box::new(|f| f.has_use("Commanded.Commands.Router")),
        render: Box::new(|| "use Commanded.Commands.Router".to_string()),
        place: Placement::Head {
            rank: Rank::Use,
            alias_sort_key: None,
        },
        requires: Vec::new(),
        stale: None,
    }
}

/// the support middlewares exist repo-wide, so these need no gate —
/// `CommandRouter.middleware_units/1`.
fn middleware_units(name: &str) -> Vec<Unit> {
    let full = format!("Sportipedia.Support.Commanded.Middleware.{name}");
    let check_module = full.clone();
    let sort_key = full.clone();
    let render = format!("alias {full}");
    let entry_name = name.to_string();
    vec![
        Unit {
            id: UnitId::RouterAlias(sort_key.clone()),
            check: Box::new(move |f| f.has_alias(&check_module)),
            render: Box::new(move || render.clone()),
            place: Placement::Head {
                rank: Rank::Alias,
                alias_sort_key: Some(sort_key),
            },
            requires: Vec::new(),
            stale: None,
        },
        Unit {
            id: UnitId::Middleware(name.to_string()),
            check: {
                let key = entry_name.clone();
                Box::new(move |f| f.has_entry("middleware", &key))
            },
            render: {
                let key = entry_name.clone();
                Box::new(move || format!("middleware {key}"))
            },
            place: Placement::AfterMacro {
                macro_name: "middleware".into(),
                predicate: MacroPredicate::Any,
                fallback: Box::new(Placement::BodyEnd),
            },
            requires: Vec::new(),
            stale: None,
        },
    ]
}

/// `CommandRouter.registration_alias/2` — the alias a registration line
/// needs, gated on the citizen it names.
fn registration_alias(full: &str, gate: Vec<(String, String)>) -> Unit {
    let check_module = full.to_string();
    let sort_key = full.to_string();
    let render = format!("alias {full}");
    Unit {
        id: UnitId::RouterAlias(full.to_string()),
        check: Box::new(move |f| f.has_alias(&check_module)),
        render: Box::new(move || render.clone()),
        requires: gate,
        place: Placement::Head {
            rank: Rank::Alias,
            alias_sort_key: Some(sort_key),
        },
        stale: None,
    }
}

fn identify_unit(ctx: &Context, aggregate: &str, gate: Vec<(String, String)>) -> Unit {
    let check_aggregate = aggregate.to_string();
    let render = {
        let prefix = ctx.render_or_panic("<-composite>/<domain-object>/");
        let aggregate = aggregate.to_string();
        move || format!("identify {aggregate}, by: :id, prefix: \"{prefix}\"")
    };
    Unit {
        id: UnitId::Identify(aggregate.to_string()),
        check: Box::new(move |f| f.has_entry("identify", &check_aggregate)),
        render: Box::new(render),
        requires: gate,
        place: Placement::AfterMacro {
            macro_name: "dispatch".into(),
            predicate: MacroPredicate::Any,
            fallback: Box::new(Placement::AfterMacro {
                macro_name: "middleware".into(),
                predicate: MacroPredicate::Any,
                fallback: Box::new(Placement::Head {
                    rank: Rank::Attribute,
                    alias_sort_key: None,
                }),
            }),
        },
        stale: None,
    }
}

fn dispatch_unit(
    command: &str,
    handler: &str,
    aggregate: &str,
    gates: Vec<(String, String)>,
) -> Unit {
    let check_command = command.to_string();
    let render = format!("dispatch {command}, to: {handler}, aggregate: {aggregate}");
    let expected_aggregate = aggregate.to_string();
    Unit {
        id: UnitId::Dispatch(command.to_string()),
        check: Box::new(move |f| f.has_entry("dispatch", &check_command)),
        render: Box::new(move || render.clone()),
        requires: gates,
        place: Placement::AfterMacroKw {
            macro_name: "dispatch".into(),
            key: "aggregate".into(),
            predicate: MacroPredicate::Eq(expected_aggregate.clone()),
            fallback: Box::new(Placement::AfterMacro {
                macro_name: "identify".into(),
                predicate: MacroPredicate::Eq(expected_aggregate),
                fallback: Box::new(Placement::BodyEnd),
            }),
        },
        stale: None,
    }
}

/// `CommandRouter.plans/1`'s gates — each named citizen must exist before
/// the line that references it may land.
fn command_gate(ctx: &Context) -> Vec<(String, String)> {
    vec![(
        Command::module_file(ctx),
        "command not generated (sparch command)".to_string(),
    )]
}

fn handler_gate(ctx: &Context) -> Vec<(String, String)> {
    vec![(
        CommandHandler::module_file(ctx),
        "handler not generated (sparch command_handler)".to_string(),
    )]
}

fn aggregate_gate(ctx: &Context) -> Vec<(String, String)> {
    vec![(
        Aggregate::module_file(ctx),
        "aggregate not generated (sparch aggregate)".to_string(),
    )]
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use crate::elixir::ElixirFile;
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

    fn units_for(name: &str) -> Vec<Unit> {
        CommandRouter.plans(&ctx_for(name)).remove(0).units
    }

    fn unit<'a>(units: &'a [Unit], label: &str) -> &'a Unit {
        units
            .iter()
            .find(|u| u.id.label() == label)
            .unwrap_or_else(|| panic!("no unit {label}"))
    }

    #[test]
    fn paths_and_modules_render_like_the_oracle() {
        let ctx = ctx_for("create-widget");
        assert_eq!(
            CommandRouter::module_file(&ctx),
            "services/api/lib/sportipedia/catalog/equipment/router.ex"
        );
        let plan = &CommandRouter.plans(&ctx)[0];
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.Catalog.Equipment.Router")
        );
        // unit-created: a composite without a router gets one
        assert!(plan.unit_created);
    }

    #[test]
    fn unit_ids_and_order_mirror_the_oracle() {
        let units = units_for("create-widget");
        let labels: Vec<String> = units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            labels,
            vec![
                "use Commanded.Commands.Router",
                "router_alias Sportipedia.Support.Commanded.Middleware.Identity",
                "middleware Identity",
                "router_alias Sportipedia.Support.Commanded.Middleware.Validate",
                "middleware Validate",
                "router_alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget",
                "router_alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidgetHandler",
                "router_alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate",
                "identify WidgetAggregate",
                "dispatch CreateWidget",
            ]
        );
    }

    #[test]
    fn the_skeleton_units_are_ungated_and_the_registrations_are_not() {
        let units = units_for("create-widget");
        // the support middlewares exist repo-wide
        for label in [
            "use Commanded.Commands.Router",
            "router_alias Sportipedia.Support.Commanded.Middleware.Identity",
            "middleware Identity",
        ] {
            assert!(unit(&units, label).requires.is_empty(), "{label}");
        }
        assert_eq!(
            unit(
                &units,
                "router_alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget"
            )
            .requires,
            vec![(
                "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/command.ex"
                    .to_string(),
                "command not generated (sparch command)".to_string(),
            )]
        );
        assert_eq!(
            unit(
                &units,
                "router_alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidgetHandler"
            )
            .requires,
            vec![(
                "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/handler.ex"
                    .to_string(),
                "handler not generated (sparch command_handler)".to_string(),
            )]
        );
        let dispatch = unit(&units, "dispatch CreateWidget");
        assert_eq!(dispatch.requires.len(), 3, "cmd, handler, aggregate");
        assert!(
            dispatch
                .requires
                .iter()
                .all(|(_, reason)| reason.contains("not generated"))
        );
    }

    #[test]
    fn renders_carry_the_exact_oracle_text() {
        let units = units_for("create-widget");
        assert_eq!(
            (unit(&units, "dispatch CreateWidget").render)(),
            "dispatch CreateWidget, to: CreateWidgetHandler, aggregate: WidgetAggregate"
        );
        assert_eq!(
            (unit(&units, "identify WidgetAggregate").render)(),
            "identify WidgetAggregate, by: :id, prefix: \"equipment/widget/\""
        );
        assert_eq!(
            (unit(
                &units,
                "router_alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate"
            )
            .render)(),
            "alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate"
        );
        assert_eq!(
            (unit(&units, "middleware Validate").render)(),
            "middleware Validate"
        );
    }

    #[test]
    fn the_gadget_router_reads_its_own_entries_present() {
        // the fixture repo's hand-finished router: use, both middleware
        // entries and the gadget registration are present; nothing widget
        // is
        let text = "defmodule Sportipedia.Catalog.Equipment.Router do\n  alias Sportipedia.Catalog.Equipment.Gadget.GadgetAggregate\n\n  use Commanded.Commands.Router\n\n  middleware Identity\n  middleware Validate\n\n  identify GadgetAggregate, by: :id, prefix: \"equipment/gadget/\"\n\n  dispatch CreateGadget, to: CreateGadgetHandler, aggregate: GadgetAggregate\nend\n";
        let file = ElixirFile::parse(text);
        let units = units_for("create-widget");
        for label in [
            "use Commanded.Commands.Router",
            "middleware Identity",
            "middleware Validate",
        ] {
            assert!((unit(&units, label).check)(&file), "{label} present");
        }
        for label in [
            "router_alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget",
            "identify WidgetAggregate",
            "dispatch CreateWidget",
        ] {
            assert!(!(unit(&units, label).check)(&file), "{label} missing");
        }
    }

    #[test]
    fn dispatch_joins_the_cluster_of_its_own_aggregate() {
        // `after_macro_kw(:dispatch, :aggregate, == aggregate)`: the widget
        // dispatch lands after the widget cluster, not after the gadget
        let text = "defmodule R do\n  middleware Identity\n\n  identify WidgetAggregate, by: :id, prefix: \"equipment/widget/\"\n\n  dispatch CreateWidget, to: CreateWidgetHandler, aggregate: WidgetAggregate\n\n  dispatch ArchiveWidget, to: ArchiveWidgetHandler, aggregate: WidgetAggregate\nend\n";
        let file = ElixirFile::parse(text);
        let units = units_for("create-widget");
        let place = &unit(&units, "dispatch CreateWidget").place;
        let (offset, _) = place
            .locate(
                &file,
                "dispatch NoteWidget, to: NoteWidgetHandler, aggregate: WidgetAggregate",
            )
            .unwrap();
        let grown = file.splice(
            offset,
            "dispatch NoteWidget, to: NoteWidgetHandler, aggregate: WidgetAggregate\n",
        );
        assert!(
            grown.contains("dispatch ArchiveWidget, to: ArchiveWidgetHandler, aggregate: WidgetAggregate\ndispatch NoteWidget"),
            "the new dispatch joins its aggregate's cluster:\n{grown}"
        );
    }

    #[test]
    fn identify_without_any_dispatch_lands_above_the_first_dispatch_cluster() {
        // the fallback chain: no dispatch at all → after middleware →
        // `identify` must sit between the middleware block and the first
        // dispatch, or above the attributes when there is no middleware
        let text =
            "defmodule R do\n  use Commanded.Commands.Router\n\n  middleware Identity\nend\n";
        let file = ElixirFile::parse(text);
        let units = units_for("create-widget");
        let place = &unit(&units, "identify WidgetAggregate").place;
        let (offset, _) = place
            .locate(
                &file,
                "identify WidgetAggregate, by: :id, prefix: \"equipment/widget/\"",
            )
            .unwrap();
        let grown = file.splice(
            offset,
            "identify WidgetAggregate, by: :id, prefix: \"equipment/widget/\"\n",
        );
        assert!(
            grown.contains("middleware Identity\nidentify WidgetAggregate"),
            "identify follows the middleware cluster:\n{grown}"
        );
    }
}
