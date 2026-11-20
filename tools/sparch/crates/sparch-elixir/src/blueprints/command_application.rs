//! The subdomain's commanded application registration — ported from
//! `SpGen.Blueprint.CommandApplication`
//! (`tools/spgen/lib/sp_gen/blueprint/command_application.ex`), the
//! registration half of `docs/architecture/blueprints/backend/domain/command.md`.
//!
//! Registers the composite's commanded router with its subdomain
//! application (`use Commanded.Application`): without the `router` line
//! the dispatch middleware of a freshly created composite answers
//! `:unregistered_command`, which no generated file complains about.
//!
//! The subdomain's `application.ex` is a registration file, and like the
//! router it is unit-created when missing, so `sparch command` works for
//! the first composite of a subdomain. Starting that application from the
//! root supervisor stays the operator's per-subdomain step (it also owns
//! the Repo and the test case template).

use sparch_model::ElementKind;

use crate::blueprints::command_router::CommandRouter;
use crate::context::Context;
use crate::elixir::Rank;
use crate::plan::{Blueprint, FilePlan, MacroPredicate, Placement, Unit, UnitId};

const APP_PATH: &str = "services/api/lib/sportipedia/<_subdomain>/application.ex";
const APP_MODULE: &str = "Sportipedia.<Subdomain>";
const ROUTER_MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.Router";
const OTP_APP: &str = "sportipedia";

pub struct CommandApplication;

impl CommandApplication {
    /// The subdomain application's path (the gate for supervised
    /// children). `CommandApplication.module_file/1`.
    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(APP_PATH)
    }
}

impl Blueprint for CommandApplication {
    fn name(&self) -> &'static str {
        "command_application"
    }

    /// The oracle derives this blueprint's sweep participation from the
    /// generator's head; the Rust sweep asks each ported module, so the
    /// registration host names the kind it registers.
    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(APP_PATH, "application router registration")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        let router = ctx.render_or_panic(ROUTER_MODULE);
        let check_router = router.clone();
        let render = format!("router {router}");
        vec![FilePlan::new(
            ctx.render_or_panic(APP_PATH),
            Some(ctx.render_or_panic(APP_MODULE)),
            vec![
                Unit {
                    id: UnitId::Use("Commanded.Application".into()),
                    check: Box::new(|f| f.has_use("Commanded.Application")),
                    render: Box::new(|| format!("use Commanded.Application, otp_app: :{OTP_APP}")),
                    place: Placement::Head {
                        rank: Rank::Use,
                        alias_sort_key: None,
                    },
                    requires: Vec::new(),
                    stale: None,
                },
                Unit {
                    id: UnitId::AppRouter(router),
                    check: Box::new(move |f| f.has_entry("router", &check_router)),
                    render: Box::new(move || render.clone()),
                    requires: vec![(
                        CommandRouter::module_file(ctx),
                        "router not generated (sparch command)".to_string(),
                    )],
                    place: Placement::AfterMacro {
                        macro_name: "router".into(),
                        predicate: MacroPredicate::Any,
                        fallback: Box::new(Placement::BodyEnd),
                    },
                    stale: None,
                },
            ],
        )]
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use crate::elixir::ElixirFile;
    use sparch_model::Model;
    use std::path::PathBuf;

    fn ctx() -> Context {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model
            .resolve("create-widget", &[ElementKind::Command])
            .expect("fixture command");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn units() -> Vec<Unit> {
        CommandApplication.plans(&ctx()).remove(0).units
    }

    #[test]
    fn paths_and_modules_render_like_the_oracle() {
        let c = ctx();
        assert_eq!(
            CommandApplication::module_file(&c),
            "services/api/lib/sportipedia/catalog/application.ex"
        );
        let plan = &CommandApplication.plans(&c)[0];
        assert_eq!(plan.module.as_deref(), Some("Sportipedia.Catalog"));
        assert!(
            plan.unit_created,
            "a subdomain without an application gets one"
        );
    }

    #[test]
    fn the_units_are_the_use_and_the_router_registration() {
        let units = units();
        let labels: Vec<String> = units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            labels,
            vec![
                "use Commanded.Application",
                "app_router Sportipedia.Catalog.Equipment.Router",
            ]
        );
        assert_eq!(
            (units[0].render)(),
            "use Commanded.Application, otp_app: :sportipedia"
        );
        assert_eq!(
            (units[1].render)(),
            "router Sportipedia.Catalog.Equipment.Router"
        );
        // the use never waits; the router line watches its file
        assert!(units[0].requires.is_empty());
        assert_eq!(
            units[1].requires,
            vec![(
                "services/api/lib/sportipedia/catalog/equipment/router.ex".to_string(),
                "router not generated (sparch command)".to_string(),
            )]
        );
    }

    #[test]
    fn presence_reads_the_parsed_registration_file() {
        let text = "defmodule Sportipedia.Catalog do\n  use Commanded.Application, otp_app: :sportipedia\n\n  router Sportipedia.Catalog.Equipment.Router\nend\n";
        let file = ElixirFile::parse(text);
        let units = units();
        assert!((units[0].check)(&file));
        assert!((units[1].check)(&file));
        let shell = ElixirFile::parse("defmodule Sportipedia.Catalog do\nend\n");
        assert!(!(units[0].check)(&shell));
        assert!(!(units[1].check)(&shell));
    }

    #[test]
    fn a_second_router_lands_in_the_router_cluster() {
        // after_macro(:router): the instrument composite's registration
        // joins the existing router lines, not the body end
        let text = "defmodule Sportipedia.Catalog do\n  use Commanded.Application, otp_app: :sportipedia\n\n  router Sportipedia.Catalog.Equipment.Router\nend\n";
        let file = ElixirFile::parse(text);
        let units = units();
        let (offset, _) = units[1]
            .place
            .locate(&file, "router Sportipedia.Catalog.Sport.Router")
            .unwrap();
        let grown = file.splice(offset, "router Sportipedia.Catalog.Sport.Router\n");
        assert!(
            grown.contains("router Sportipedia.Catalog.Equipment.Router\nrouter Sportipedia.Catalog.Sport.Router"),
            "router lines cluster:\n{grown}"
        );
    }
}
