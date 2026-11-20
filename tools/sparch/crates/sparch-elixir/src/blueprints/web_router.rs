use sparch_model::ElementKind;

use crate::blueprints::controller::Controller;
use crate::context::Context;
use crate::plan::{Blueprint, FilePlan, Placement, ScopeLevel, Unit, UnitId};

const ROUTER_PATH: &str = "services/api/lib/sportipedia_web/router.ex";
const ROUTER_MODULE: &str = "SportipediaWeb.Router";

pub struct WebRouter;

impl WebRouter {
    pub fn scope_spec(ctx: &Context) -> Vec<ScopeLevel> {
        vec![
            (
                format!("/{}", ctx.subdomain),
                Some(format!(
                    "SportipediaWeb.{}",
                    Context::pascal(&ctx.subdomain)
                )),
            ),
            (
                format!("/{}", ctx.composite),
                Some(Context::pascal(&ctx.composite)),
            ),
            (
                format!("/{}s", ctx.constituent),
                Some(Context::pascal(&ctx.constituent)),
            ),
        ]
    }
}

impl Blueprint for WebRouter {
    fn name(&self) -> &'static str {
        "web_router"
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command, ElementKind::Query]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(ROUTER_PATH, "authenticated scope route")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        let op = ctx.op_snake();
        let verb = if ctx.element.kind == ElementKind::Command {
            "post"
        } else {
            "get"
        };
        let chain = WebRouter::scope_spec(ctx);
        let paths: Vec<String> = chain.iter().map(|(path, _alias)| path.clone()).collect();
        let controller = format!("{}Controller", Context::pascal(&ctx.constituent));
        let line = format!(
            "{verb} \"{}\", {controller}, :{op}",
            Controller::route_path(ctx)
        );
        let action = format!(":{op}");
        let check_action = action.clone();
        let check_paths = paths.clone();
        let render = line.clone();
        let mut plan = FilePlan::new(
            ROUTER_PATH.to_string(),
            Some(ROUTER_MODULE.to_string()),
            vec![Unit {
                id: UnitId::Route(action),
                check: Box::new(move |f| f.route_present(verb, &check_action, &check_paths)),
                render: Box::new(move || render.clone()),
                requires: vec![(
                    Controller::module_file(ctx),
                    "controller not generated (sparch controller)".to_string(),
                )],
                place: Placement::Scope { chain },
                stale: None,
            }],
        );
        plan.unit_created = false;
        vec![plan]
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use crate::elixir::ElixirFile;
    use sparch_model::Model;
    use std::path::PathBuf;

    const ROUTER: &str = r#"defmodule SportipediaWeb.Router do
  use SportipediaWeb, :router

  scope "/catalog", SportipediaWeb.Catalog do
    pipe_through [:api, :catalog]

    scope "/equipment", Equipment do
      scope "/gadgets", Gadget do
        post "/create-gadget", GadgetController, :create_gadget
      end
    end
  end
end
"#;

    fn ctx_for(name: &str) -> Context {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model
            .resolve(name, &WebRouter.source_kinds())
            .expect("fixture operation");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn route_unit(ctx: &Context) -> Unit {
        WebRouter.plans(ctx).remove(0).units.remove(0)
    }

    #[test]
    fn the_scope_spec_walks_subdomain_composite_and_plural_constituent() {
        let chain = WebRouter::scope_spec(&ctx_for("create-widget"));
        assert_eq!(
            chain,
            vec![
                (
                    "/catalog".to_string(),
                    Some("SportipediaWeb.Catalog".to_string())
                ),
                ("/equipment".to_string(), Some("Equipment".to_string())),
                ("/widgets".to_string(), Some("Widget".to_string())),
            ]
        );
    }

    #[test]
    fn the_line_is_the_verb_the_path_the_controller_and_the_action() {
        let command = route_unit(&ctx_for("create-widget"));
        assert_eq!(command.id.label(), "route :create_widget");
        assert_eq!(
            (command.render)(),
            "post \"/create-widget\", WidgetController, :create_widget"
        );
        let read = route_unit(&ctx_for("read-widget"));
        assert_eq!(
            (read.render)(),
            "get \"/:id_or_slug\", WidgetController, :read_widget"
        );
        let list = route_unit(&ctx_for("list-widgets"));
        assert_eq!(
            (list.render)(),
            "get \"/\", WidgetController, :list_widgets"
        );
        assert_eq!(
            list.requires,
            vec![(
                "services/api/lib/sportipedia_web/catalog/equipment/widget/widget_controller.ex"
                    .to_string(),
                "controller not generated (sparch controller)".to_string()
            )]
        );
    }

    #[test]
    fn the_check_finds_a_route_only_inside_its_own_scope_chain() {
        let present = ElixirFile::parse(
            "defmodule R do\n  scope \"/catalog\", SportipediaWeb.Catalog do\n    scope \"/equipment\", Equipment do\n      scope \"/widgets\", Widget do\n        post \"/create-widget\", WidgetController, :create_widget\n      end\n    end\n  end\nend\n",
        );
        let paths: Vec<String> = WebRouter::scope_spec(&ctx_for("create-widget"))
            .into_iter()
            .map(|(path, _)| path)
            .collect();
        assert!((route_unit(&ctx_for("create-widget")).check)(&present));
        assert!(
            present.route_present("post", ":create_widget", &paths),
            "the route sits inside the full chain"
        );
        assert!(
            !present.route_present("post", ":create_widget", &["/athletes".to_string()]),
            "another subdomain holds no widget route"
        );
        assert!(
            !present
                .calls("post")
                .iter()
                .any(|entry| entry.action_key() == ":edit_widget"),
            "the same file holds no read-widget route"
        );

        let nested_only = ElixirFile::parse(ROUTER);
        assert!(
            !(route_unit(&ctx_for("create-widget")).check)(&nested_only),
            "the widget scope does not exist yet"
        );
        assert!(
            nested_only.route_present("post", ":create_gadget", &["/catalog".to_string()]),
            "a route inside the outer scope counts when the chain stops there"
        );
        let empty = ElixirFile::parse("defmodule R do\nend\n");
        assert!(!(route_unit(&ctx_for("create-widget")).check)(&empty));
    }

    #[test]
    fn the_missing_tail_materializes_as_nested_scopes() {
        let file = ElixirFile::parse(ROUTER);
        let chain = WebRouter::scope_spec(&ctx_for("create-widget"));
        let (offset, depth) = file
            .insert_offset_scope(&chain)
            .expect("the outer scopes exist");
        assert_eq!(depth, 2, "catalog and equipment match, widgets does not");
        let next = Placement::Scope {
            chain: chain.clone(),
        }
        .apply(
            &file,
            "post \"/create-widget\", WidgetController, :create_widget",
        )
        .expect("the route lands");
        assert!(
            next.contains(
                "scope \"/gadgets\", Gadget do\n        post \"/create-gadget\", GadgetController, :create_gadget\n      end\nscope \"/widgets\", Widget do\npost \"/create-widget\", WidgetController, :create_widget\nend\n    end"
            ),
            "the new scope is appended inside /equipment:\n{next}"
        );
        assert!(ElixirFile::parse(&next).parsed(), "{next}");
        assert!(
            ROUTER[offset..].starts_with("    end\n  end\nend\n"),
            "the splice point is the line that closes the matched scope"
        );

        let absent =
            ElixirFile::parse("defmodule R do\n  scope \"/other\", Other do\n  end\nend\n");
        assert!(absent.insert_offset_scope(&chain).is_none());

        let grown = ElixirFile::parse(
            "defmodule R do\n  scope \"/catalog\", SportipediaWeb.Catalog do\n    scope \"/equipment\", Equipment do\n      scope \"/widgets\", Widget do\n        post \"/create-widget\", WidgetController, :create_widget\n      end\n    end\n  end\nend\n",
        );
        let (_, depth) = grown.insert_offset_scope(&chain).expect("all match");
        assert_eq!(depth, 3, "a complete chain inserts the bare route line");
    }

    #[test]
    fn the_registration_host_is_never_created_by_this_plan() {
        let plan = WebRouter.plans(&ctx_for("create-widget")).remove(0);
        assert!(!plan.unit_created);
        assert_eq!(plan.path, ROUTER_PATH);
        assert_eq!(plan.module.as_deref(), Some(ROUTER_MODULE));
    }
}
