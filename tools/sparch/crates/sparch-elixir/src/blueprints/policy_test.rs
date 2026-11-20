use sparch_model::ElementKind;

use crate::blueprints::policy::Policy;
use crate::blueprints::test_case::{self, Describe, Options};
use crate::context::Context;
use crate::plan::{Blueprint, FilePlan};
use crate::templates;

const TEST_PATH: &str = "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operations/<_operation>_test.exs";
const TEST_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test";

pub struct PolicyTest;

impl Blueprint for PolicyTest {
    fn name(&self) -> &'static str {
        "policy_test"
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command, ElementKind::Query]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(TEST_PATH, "allowed and denied calls")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        vec![test_case::plan(
            ctx,
            Options {
                path_template: TEST_PATH,
                module_template: TEST_MODULE,
                extra_vars: Default::default(),
                alias_templates: vec![Policy::module_template()],
                alias_modules: Vec::new(),
                requires: vec![(
                    Policy::module_file(ctx),
                    "policy not generated (sparch policy)".to_string(),
                )],
                alias_requires: None,
                describes: vec![Describe {
                    subject_template: "Policy",
                    body: Box::new(describe_body),
                    alternates: vec!["Policy - <_operation>"],
                }],
            },
        )]
    }
}

pub fn describe_body(ctx: &Context, subject: &str) -> String {
    let policy = "Policy";
    let action = ctx.op_snake();
    let guest = if Policy::guest_allowed(ctx) {
        ":ok"
    } else {
        ":error"
    };

    let mut tests = vec![format!(
        "test \"denies or allows guests for {action}\" do\n  assert {policy}.authorize(:{action}, nil, %{{}}) == {guest}\nend"
    )];
    if Policy::admin_only(ctx) {
        tests.push(format!(
            "test \"denies an authenticated user who is not an admin for {action}\" do\n  assert {policy}.authorize(:{action}, %{{id: UUID.uuid4(), role: \"user\"}}, %{{}}) == :error\nend"
        ));
        tests.push(format!(
            "test \"allows admins for {action}\" do\n  assert {policy}.authorize(:{action}, %{{id: UUID.uuid4(), role: \"admin\"}}, %{{}}) == :ok\nend"
        ));
    } else {
        tests.push(format!(
            "test \"allows users for {action}\" do\n  assert {policy}.authorize(:{action}, %{{id: UUID.uuid4(), role: \"user\"}}, %{{}}) == :ok\nend"
        ));
    }

    format!(
        "describe \"{subject}\" do\n{}\nend",
        templates::indent(&tests.join("\n\n"), 2)
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
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

    fn plan(name: &str) -> FilePlan {
        PolicyTest.plans(&ctx_for(name)).remove(0)
    }

    #[test]
    fn the_test_file_plan_lands_alias_and_describe_behind_the_policy_gate() {
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
                "test_alias Sportipedia.Catalog.Equipment.Widget.Policy",
                "describe Policy",
            ]
        );
        for unit in &plan.units[2..] {
            assert_eq!(
                unit.requires,
                vec![(
                    "services/api/lib/sportipedia/catalog/equipment/widget/policy.ex".to_string(),
                    "policy not generated (sparch policy)".to_string(),
                )],
                "{}",
                unit.id.label()
            );
        }
    }

    #[test]
    fn the_deny_allow_shape_tests_guest_and_user() {
        let body = describe_body(&ctx_for("create-widget"), "Policy");
        assert!(
            body.starts_with(
                "describe \"Policy\" do\n  test \"denies or allows guests for create_widget\" do\n"
            ),
            "{body}"
        );
        assert!(
            body.contains("assert Policy.authorize(:create_widget, nil, %{}) == :error"),
            "{body}"
        );
        assert!(
            body.contains("test \"allows users for create_widget\" do"),
            "{body}"
        );
        assert!(body.contains("role: \"user\"}, %{}) == :ok"), "{body}");
        assert!(!body.contains("admins"), "not an admin-only list:\n{body}");
        assert!(body.ends_with("end\nend"), "heredoc shape:\n{body}");
    }

    #[test]
    fn the_guest_shape_keeps_the_answer_rule() {
        let body = describe_body(&ctx_for("read-widget"), "Policy");
        assert!(
            body.contains("assert Policy.authorize(:read_widget, nil, %{}) == :ok"),
            "{body}"
        );
        assert!(
            body.contains("test \"allows users for read_widget\" do"),
            "{body}"
        );
    }

    #[test]
    fn the_admin_only_shape_states_all_three_answers() {
        let ctx = ctx_for("archive-position");
        assert!(Policy::admin_only(&ctx));
        let body = describe_body(&ctx, "Policy");
        assert!(
            body.contains("assert Policy.authorize(:archive_position, nil, %{}) == :error"),
            "{body}"
        );
        assert!(
            body.contains(
                "test \"denies an authenticated user who is not an admin for archive_position\" do"
            ),
            "{body}"
        );
        assert!(body.contains("role: \"admin\"}, %{}) == :ok"), "{body}");
        assert!(!body.contains("\"allows users for"), "{body}");
    }

    #[test]
    fn the_describe_check_accepts_the_alternate_spelling() {
        let units = plan("create-widget").units;
        let describe = units
            .iter()
            .find(|u| u.id.label() == "describe Policy")
            .expect("the describe");
        let existing = crate::elixir::ElixirFile::parse(
            "defmodule T do\n  describe \"Policy - create_widget\" do\n  end\nend\n",
        );
        assert!((describe.check)(&existing));
    }
}
