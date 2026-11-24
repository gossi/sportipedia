use sparch_model::ElementKind;

use crate::context::Context;
use crate::elixir::Rank;
use crate::plan::{Blueprint, FilePlan, Placement, Unit, UnitId};

const PATH: &str =
    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/policy.ex";
const MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Policy";

pub struct Policy;

impl Policy {
    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(PATH)
    }

    pub fn module_template() -> &'static str {
        MODULE
    }

    pub fn admin_only(ctx: &Context) -> bool {
        ctx.actors.len() == 1 && ctx.actors[0] == "admin"
    }

    pub fn guest_allowed(ctx: &Context) -> bool {
        ctx.actors.iter().any(|actor| actor == "guest")
    }

    pub fn clauses(ctx: &Context) -> String {
        let action = format!(":{}", ctx.op_snake());

        if Policy::guest_allowed(ctx) {
            format!("def authorize({action}, _user, _params), do: :ok")
        } else if Policy::admin_only(ctx) {
            format!(
                "def authorize({action}, user, _params) when is_guest?(user), do: :error\ndef authorize({action}, user, _params) when is_admin?(user), do: :ok\ndef authorize({action}, user, _params) when is_user?(user), do: :error"
            )
        } else {
            format!(
                "def authorize({action}, user, _params) when is_guest?(user), do: :error\ndef authorize({action}, user, _params) when is_user?(user), do: :ok"
            )
        }
    }
}

impl Blueprint for Policy {
    fn name(&self) -> &'static str {
        "policy"
    }

    fn description(&self) -> Option<&'static str> {
        Some("Generates the authorization policy for an operation")
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command, ElementKind::Query]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(PATH, "authorize clauses per action")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        vec![FilePlan::new(
            ctx.render_or_panic(PATH),
            Some(ctx.render_or_panic(MODULE)),
            units(ctx),
        )]
    }
}

fn units(ctx: &Context) -> Vec<Unit> {
    let action = format!(":{}", ctx.op_snake());

    let doc = format!(
        "@moduledoc \"\"\"\nAuthorizes {} operations based on user roles.\n\"\"\"",
        ctx.constituent
    );
    let behaviour = Unit {
        id: UnitId::Behaviour("Bodyguard.Policy".into()),
        check: Box::new(|f| f.attr_names("behaviour", "Bodyguard.Policy")),
        render: Box::new(|| "@behaviour Bodyguard.Policy".to_string()),
        place: Placement::Head {
            rank: Rank::Attribute,
            alias_sort_key: None,
        },
        requires: Vec::new(),
        stale: None,
    };
    let import = Unit {
        id: UnitId::Import("Sportipedia.Auth.Roles".into()),
        check: Box::new(|f| f.has_import("Sportipedia.Auth.Roles")),
        render: Box::new(|| "import Sportipedia.Auth.Roles".to_string()),
        place: Placement::Head {
            rank: Rank::Import,
            alias_sort_key: None,
        },
        requires: Vec::new(),
        stale: None,
    };
    let check_action = action.clone();
    let render = Policy::clauses(ctx);
    let authorize = Unit {
        id: UnitId::Authorize(action),
        check: Box::new(move |f| f.has_def_head_arg("authorize", 3, &check_action)),
        render: Box::new(move || render.clone()),
        place: Placement::AfterDef {
            name: "authorize".to_string(),
            arity: 3,
        },
        requires: Vec::new(),
        stale: None,
    };

    vec![
        Unit {
            id: UnitId::Moduledoc,
            check: Box::new(|f| f.has_moduledoc()),
            render: Box::new(move || doc.clone()),
            place: Placement::Head {
                rank: Rank::Moduledoc,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        },
        behaviour,
        import,
        authorize,
    ]
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
            .resolve(name, &[ElementKind::Command, ElementKind::Query])
            .expect("fixture operation");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn units_for(name: &str) -> Vec<Unit> {
        Policy.plans(&ctx_for(name)).remove(0).units
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
    fn paths_and_modules_render_as_the_model_expects() {
        let ctx = ctx_for("create-widget");
        assert_eq!(
            Policy::module_file(&ctx),
            "services/api/lib/sportipedia/catalog/equipment/widget/policy.ex"
        );
        let plan = &Policy.plans(&ctx)[0];
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.Catalog.Equipment.Widget.Policy")
        );
        assert!(plan.unit_created);
    }

    #[test]
    fn unit_ids_and_order_match_the_model() {
        let labels: Vec<String> = units_for("create-widget")
            .iter()
            .map(|u| u.id.label())
            .collect();
        assert_eq!(
            labels,
            vec![
                "moduledoc",
                "behaviour Bodyguard.Policy",
                "import Sportipedia.Auth.Roles",
                "authorize :create_widget",
            ]
        );
    }

    #[test]
    fn the_directive_units_carry_the_expected_text() {
        let units = units_for("create-widget");
        assert_eq!(
            render(&units, "moduledoc"),
            "@moduledoc \"\"\"\nAuthorizes widget operations based on user roles.\n\"\"\""
        );
        assert_eq!(
            render(&units, "behaviour Bodyguard.Policy"),
            "@behaviour Bodyguard.Policy"
        );
        assert_eq!(
            render(&units, "import Sportipedia.Auth.Roles"),
            "import Sportipedia.Auth.Roles"
        );
    }

    #[test]
    fn the_user_only_actor_list_is_the_deny_allow_pair() {
        let units = units_for("create-widget");
        assert_eq!(
            render(&units, "authorize :create_widget"),
            "def authorize(:create_widget, user, _params) when is_guest?(user), do: :error\ndef authorize(:create_widget, user, _params) when is_user?(user), do: :ok"
        );
    }

    #[test]
    fn a_guest_among_the_actors_is_one_open_clause() {
        for (name, action) in [
            ("read-widget", "read_widget"),
            ("list-widgets", "list_widgets"),
        ] {
            let units = units_for(name);
            assert_eq!(
                render(&units, &format!("authorize :{action}")),
                format!("def authorize(:{action}, _user, _params), do: :ok")
            );
        }
    }

    #[test]
    fn an_admin_only_actor_list_denies_every_other_authenticated_user() {
        let ctx = ctx_for("archive-position");
        assert!(Policy::admin_only(&ctx));
        let plan = &Policy.plans(&ctx)[0];
        assert_eq!(
            (unit(&plan.units, "authorize :archive_position").render)(),
            "def authorize(:archive_position, user, _params) when is_guest?(user), do: :error\ndef authorize(:archive_position, user, _params) when is_admin?(user), do: :ok\ndef authorize(:archive_position, user, _params) when is_user?(user), do: :error"
        );
    }

    #[test]
    fn the_clause_lands_with_the_other_authorize_clauses() {
        let units = units_for("create-widget");
        let place = &unit(&units, "authorize :create_widget").place;
        assert!(matches!(
            place,
            Placement::AfterDef { name, arity } if name == "authorize" && *arity == 3
        ));
        let existing = ElixirFile::parse(
            "defmodule M.Policy do\n  def authorize(:edit_widget, user, _params) when is_guest?(user), do: :error\n\n  def authorize(:edit_widget, user, _params) when is_user?(user), do: :ok\nend\n",
        );
        let (offset, _) = place
            .locate(
                &existing,
                "def authorize(:create_widget, user, _params) when is_guest?(user), do: :error",
            )
            .unwrap();
        let next = existing.splice(
            offset,
            "def authorize(:create_widget, user, _params) when is_guest?(user), do: :error\n",
        );
        assert!(
            next.contains("is_user?(user), do: :ok\ndef authorize(:create_widget"),
            "the new clause joins the authorize run:\n{next}"
        );
    }

    #[test]
    fn the_clause_check_reads_the_action_atom_in_the_head() {
        let units = units_for("create-widget");
        let clause = unit(&units, "authorize :create_widget");
        let authored = ElixirFile::parse(
            "defmodule M.Policy do\n  def authorize(:create_widget, user, _params) when is_guest?(user), do: :error\n\n  def authorize(:edit_widget, user, _params) when is_guest?(user), do: :error\nend\n",
        );
        assert!((clause.check)(&authored));
        let other = ElixirFile::parse(
            "defmodule M.Policy do\n  def authorize(:edit_widget, user, _params) when is_guest?(user), do: :error\nend\n",
        );
        assert!(!(clause.check)(&other), "another action is not this one");
    }

    #[test]
    fn the_finished_policy_file_is_fully_present() {
        let text = "defmodule Sportipedia.Catalog.Equipment.Widget.Policy do\n  @moduledoc \"\"\"\n  Authorizes widget operations based on user roles.\n  \"\"\"\n  import Sportipedia.Auth.Roles\n  @behaviour Bodyguard.Policy\n  def authorize(:create_widget, user, _params) when is_guest?(user), do: :error\n  def authorize(:create_widget, user, _params) when is_user?(user), do: :ok\nend\n";
        let file = ElixirFile::parse(text);
        for unit in &units_for("create-widget") {
            assert!((unit.check)(&file), "{} must read present", unit.id.label());
        }
    }
}
