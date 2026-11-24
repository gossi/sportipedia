use sparch_model::ElementKind;

use crate::blueprints::projector::Projector;
use crate::context::Context;
use crate::elixir::Rank;
use crate::plan::{Blueprint, FilePlan, Placement, Unit, UnitId};

const COMPOSITE_PATH: &str = "services/api/lib/sportipedia/<_subdomain>/<composite>/supervisor.ex";
const COMPOSITE_MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.Supervisor";
const SUBDOMAIN_PATH: &str = "services/api/lib/sportipedia/<_subdomain>/supervisor.ex";
const SUBDOMAIN_MODULE: &str = "Sportipedia.<Subdomain>.Supervisor";

pub struct ProjectorSupervisor;

impl Blueprint for ProjectorSupervisor {
    fn name(&self) -> &'static str {
        "projector_supervisor"
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Event]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![
            (COMPOSITE_PATH, "composite projector children"),
            (SUBDOMAIN_PATH, "fallback projector children"),
        ]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        let module = ctx.render_or_panic(Projector::module_template());
        let (path, supervisor) = target(ctx);

        let mut units = skeleton_units();
        units.push(child_unit(&module, ctx));

        let mut plan = FilePlan::new(path, Some(supervisor), units);
        plan.unit_created = true;
        vec![plan]
    }
}

fn target(ctx: &Context) -> (String, String) {
    for (path_tpl, module_tpl) in [
        (COMPOSITE_PATH, COMPOSITE_MODULE),
        (SUBDOMAIN_PATH, SUBDOMAIN_MODULE),
    ] {
        let path = ctx.render_or_panic(path_tpl);
        if ctx.repo_root.join(&path).exists() {
            return (path, ctx.render_or_panic(module_tpl));
        }
    }
    (
        ctx.render_or_panic(SUBDOMAIN_PATH),
        ctx.render_or_panic(SUBDOMAIN_MODULE),
    )
}

fn skeleton_units() -> Vec<Unit> {
    vec![
        Unit {
            id: UnitId::Use("Supervisor".into()),
            check: Box::new(|f| f.has_use("Supervisor")),
            render: Box::new(|| "use Supervisor".to_string()),
            place: Placement::Head {
                rank: Rank::Use,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        },
        Unit {
            id: UnitId::Def("start_link".into(), 1),
            check: Box::new(|f| f.has_def("start_link", 1)),
            render: Box::new(|| {
                "def start_link(arg) do\n  Supervisor.start_link(__MODULE__, arg, name: __MODULE__)\nend"
                    .to_string()
            }),
            place: Placement::BodyEnd,
            requires: Vec::new(),
            stale: None,
        },
        Unit {
            id: UnitId::Def("init".into(), 1),
            check: Box::new(|f| f.has_def("init", 1)),
            render: Box::new(|| {
                "def init(_arg) do\n  children = []\n\n  Supervisor.init(children, strategy: :one_for_one)\nend"
                    .to_string()
            }),
            place: Placement::BodyEnd,
            requires: Vec::new(),
            stale: None,
        },
    ]
}

fn child_unit(module: &str, ctx: &Context) -> Unit {
    let check_module = module.to_string();
    let render = module.to_string();
    Unit {
        id: UnitId::Child(module.to_string()),
        check: Box::new(move |f| f.has_child(&check_module)),
        render: Box::new(move || render.clone()),
        requires: vec![(
            Projector::module_file(ctx),
            "projector not generated (sparch projector)".to_string(),
        )],
        place: Placement::ChildrenList,
        stale: None,
    }
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

    fn units_for(event: &str) -> Vec<Unit> {
        ProjectorSupervisor.plans(&ctx_for(event)).remove(0).units
    }

    #[test]
    fn the_registration_targets_the_existing_subdomain_supervisor() {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/repo");
        let mut ctx = ctx_for("widget-created");
        ctx.repo_root = root.canonicalize().expect("fixture repo");
        let plan = &ProjectorSupervisor.plans(&ctx)[0];
        assert_eq!(
            plan.path,
            "services/api/lib/sportipedia/catalog/supervisor.ex"
        );
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.Catalog.Supervisor")
        );
        assert!(plan.unit_created);
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
                "use Supervisor",
                "start_link/1",
                "init/1",
                "child Sportipedia.Catalog.Equipment.Widget.WidgetProjector",
            ]
        );
    }

    #[test]
    fn the_child_waits_for_the_projector_module() {
        let units = units_for("widget-created");
        let child = units
            .iter()
            .find(|u| u.id.label() == "child Sportipedia.Catalog.Equipment.Widget.WidgetProjector")
            .expect("the child");
        assert_eq!(
            child.requires,
            vec![(
                "services/api/lib/sportipedia/catalog/equipment/widget/projector.ex".to_string(),
                "projector not generated (sparch projector)".to_string(),
            )]
        );
        assert!(matches!(child.place, Placement::ChildrenList));
        assert_eq!(
            (child.render)(),
            "Sportipedia.Catalog.Equipment.Widget.WidgetProjector"
        );
        for skeleton in &units[..3] {
            assert!(skeleton.requires.is_empty(), "{}", skeleton.id.label());
        }
    }

    #[test]
    fn the_skeleton_renders_the_supervisor_start_and_children() {
        let units = units_for("widget-created");
        let texts: Vec<(String, String)> =
            units.iter().map(|u| (u.id.label(), (u.render)())).collect();
        assert_eq!(texts[0].1, "use Supervisor");
        assert_eq!(
            texts[1].1,
            "def start_link(arg) do\n  Supervisor.start_link(__MODULE__, arg, name: __MODULE__)\nend"
        );
        assert_eq!(
            texts[2].1,
            "def init(_arg) do\n  children = []\n\n  Supervisor.init(children, strategy: :one_for_one)\nend"
        );
    }

    #[test]
    fn a_subdomain_supervisor_without_the_child_reads_it_missing() {
        let text = "defmodule Sportipedia.Catalog.Supervisor do\n  use Supervisor\n\n  def start_link(arg) do\n    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)\n  end\n\n  def init(_arg) do\n    children = [\n      Sportipedia.Catalog\n    ]\n\n    Supervisor.init(children, strategy: :one_for_one)\n  end\nend\n";
        let file = ElixirFile::parse(text);
        let units = units_for("widget-created");
        for skeleton in &units[..3] {
            assert!((skeleton.check)(&file), "{} present", skeleton.id.label());
        }
        assert!(!(units[3].check)(&file), "the projector child is missing");
    }
}
