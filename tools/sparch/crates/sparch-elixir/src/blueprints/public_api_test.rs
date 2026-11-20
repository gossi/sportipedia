use sparch_model::{Element, ElementKind};

use crate::blueprints::public_api::PublicApi;
use crate::blueprints::test_case::{self, Describe, Options};
use crate::context::{Befield, Context, Operation};
use crate::plan::{Blueprint, FilePlan};
use crate::templates;

const TEST_PATH: &str = "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operations/<_operation>_test.exs";
const TEST_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test";

pub struct PublicAPITest;

impl Blueprint for PublicAPITest {
    fn name(&self) -> &'static str {
        "public_api_test"
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command, ElementKind::Query]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(TEST_PATH, "public function call tests")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        vec![test_case::plan(
            ctx,
            Options {
                path_template: TEST_PATH,
                module_template: TEST_MODULE,
                extra_vars: Default::default(),
                alias_templates: vec![PublicApi::module_template()],
                alias_modules: Vec::new(),
                requires: vec![(
                    PublicApi::module_file(ctx),
                    "public API not generated (sparch public_api)".to_string(),
                )],
                alias_requires: None,
                describes: vec![Describe {
                    subject_template: "Public API",
                    body: Box::new(describe_body),
                    alternates: vec!["Public API - <_operation>"],
                }],
            },
        )]
    }
}

pub fn describe_body(ctx: &Context, subject: &str) -> String {
    let api = Context::pascal(&ctx.constituent);
    let op = ctx.op_snake();
    let body = public_params(ctx, &ctx.element);

    let tests: Vec<String> = match ctx.element.kind {
        ElementKind::Command => match ctx.operation {
            Some(Operation::Delete) => delete_tests(ctx, &api, &op),
            Some(Operation::None) => none_tests(ctx, &api, &op, &body),
            _ => command_tests(ctx, &api, &op, &body),
        },
        _ => {
            if ctx.collection() {
                vec![format!(
                    "test \"{op} lists read models\" do\n  assert {{:ok, data}} = {api}.{op}(%JSONAPI.Config{{}})\n\n  assert is_list(data)\nend"
                )]
            } else {
                vec![format!(
                    "test \"{op} returns :not_found for unknown {}\" do\n  assert {{:error, :not_found}} = {api}.{op}(UUID.uuid4())\nend",
                    ctx.constituent
                )]
            }
        }
    };

    format!(
        "describe \"{subject}\" do\n{}\nend",
        templates::indent(&tests.join("\n\n"), 2)
    )
}

fn param_expr(ctx: &Context, body: &str) -> String {
    match ctx.operation {
        Some(Operation::Delete) => "id".to_string(),
        _ => format!("%{{{body}}}"),
    }
}

fn command_tests(ctx: &Context, api: &str, op: &str, body: &str) -> Vec<String> {
    let success = format!(
        "test \"{op} succeeds\" do\n  assert {{:ok, read_model}} = {api}.{op}({})\n\n  assert read_model.id != nil\nend",
        param_expr(ctx, body)
    );
    let validation = format!(
        "test \"{op} returns validation errors\" do\n  assert {{:error, {{:validation_failure, _errors}}}} = {api}.{op}(%{{}})\nend"
    );

    match ctx.operation {
        Some(Operation::Update) => match create_operation(ctx) {
            None => vec![success, validation],
            Some((create_op, create_body)) => vec![format!(
                "test \"{op} succeeds\" do\n  assert {{:ok, created}} = {api}.{create_op}({create_body})\n\n  assert {{:ok, read_model}} = {api}.{op}(%{{id: created.id}})\n\n  assert read_model.id == created.id\nend"
            )],
        },
        _ => vec![success, validation],
    }
}

fn delete_tests(ctx: &Context, api: &str, op: &str) -> Vec<String> {
    let unknown = format!(
        "test \"{op} fails for an unknown {}\" do\n  assert {{:error, _}} = {api}.{op}(UUID.uuid4())\nend",
        ctx.constituent
    );

    match create_operation(ctx) {
        None => vec![unknown],
        Some((create_op, create_body)) => vec![
            format!(
                "test \"{op} succeeds\" do\n  assert {{:ok, created}} = {api}.{create_op}({create_body})\n\n  assert :ok = {api}.{op}(created.id)\nend"
            ),
            unknown,
        ],
    }
}

fn none_tests(ctx: &Context, api: &str, op: &str, body: &str) -> Vec<String> {
    vec![
        format!(
            "test \"{op} succeeds\" do\n  assert :ok = {api}.{op}({})\nend",
            param_expr(ctx, body)
        ),
        format!(
            "test \"{op} returns validation errors\" do\n  assert {{:error, {{:validation_failure, _errors}}}} = {api}.{op}(%{{}})\nend"
        ),
    ]
}

fn create_operation(ctx: &Context) -> Option<(String, String)> {
    let create = ctx.model.elements.iter().find(|el| {
        el.kind == ElementKind::Command
            && el.aggregate_name() == Some(ctx.constituent.as_str())
            && crate::context::derive_operation(&ctx.model, el) == Some(Operation::Create)
    })?;
    Some((
        create.name.replace('-', "_"),
        format!("%{{{}}}", public_params(ctx, create)),
    ))
}

fn public_params(ctx: &Context, element: &Element) -> String {
    let unique = ctx.unique_fields();

    sparch_model::fields(element)
        .iter()
        .filter(|f| f.required && f.name != "id")
        .map(|f| {
            let field = Befield::from_field(f);
            let value = if unique.contains(&field.name) {
                format!("\"sample-{}-#{{UUID.uuid4()}}\"", field.name)
            } else {
                templates::sample_value(ctx, &field)
            };
            format!("{}: {value}", field.name)
        })
        .collect::<Vec<_>>()
        .join(", ")
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
        PublicAPITest.plans(&ctx_for(name)).remove(0)
    }

    #[test]
    fn the_test_file_plan_lands_alias_and_describe_behind_the_port_gate() {
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
                "test_alias Sportipedia.Catalog.Equipment.Widget",
                "describe Public API",
            ]
        );
        for unit in &plan.units[2..] {
            assert_eq!(
                unit.requires,
                vec![(
                    "services/api/lib/sportipedia/catalog/equipment/widget/public_api.ex"
                        .to_string(),
                    "public API not generated (sparch public_api)".to_string(),
                )],
                "{}",
                unit.id.label()
            );
        }
    }

    #[test]
    fn the_create_shape_exercises_success_and_the_failure_contract() {
        let body = describe_body(&ctx_for("create-widget"), "Public API");
        assert!(
            body.starts_with("describe \"Public API\" do\n  test \"create_widget succeeds\" do\n"),
            "{body}"
        );
        assert!(
            body.contains("assert {:ok, read_model} = Widget.create_widget(%{title: \"Pommel Horse\", slug: \"sample-slug-#{UUID.uuid4()}\"})"),
            "the unique field gets a fresh value:\n{body}"
        );
        assert!(body.contains("assert read_model.id != nil"), "{body}");
        assert!(
            body.contains("test \"create_widget returns validation errors\" do"),
            "{body}"
        );
        assert!(
            body.contains(
                "assert {:error, {:validation_failure, _errors}} = Widget.create_widget(%{})"
            ),
            "{body}"
        );
        assert!(body.ends_with("end\nend"), "heredoc shape:\n{body}");
    }

    #[test]
    fn the_update_shape_seeds_through_the_create_operation() {
        let body = describe_body(&ctx_for("edit-widget"), "Public API");
        assert!(
            body.contains("assert {:ok, created} = Widget.create_widget(%{title: \"Vaulting Table\", slug: \"sample-slug-#{UUID.uuid4()}\"})"),
            "{body}"
        );
        assert!(
            body.contains("assert {:ok, read_model} = Widget.edit_widget(%{id: created.id})"),
            "{body}"
        );
        assert!(
            body.contains("assert read_model.id == created.id"),
            "{body}"
        );
        assert!(
            !body.contains("returns validation errors"),
            "the seeded shape owns the test:\n{body}"
        );
    }

    #[test]
    fn the_delete_shape_addresses_the_created_id_and_the_unknown_one() {
        let body = describe_body(&ctx_for("archive-widget"), "Public API");
        assert!(
            body.contains("test \"archive_widget succeeds\" do"),
            "{body}"
        );
        assert!(
            body.contains("assert :ok = Widget.archive_widget(created.id)"),
            "{body}"
        );
        assert!(
            body.contains("test \"archive_widget fails for an unknown widget\" do"),
            "{body}"
        );
        assert!(
            body.contains("assert {:error, _} = Widget.archive_widget(UUID.uuid4())"),
            "{body}"
        );
    }

    #[test]
    fn the_none_shape_answers_the_dispatch_result() {
        let body = describe_body(&ctx_for("note-widget"), "Public API");
        assert!(
            body.contains("assert :ok = Widget.note_widget(%{comment: \"sample-comment\"})"),
            "{body}"
        );
        assert!(
            body.contains("test \"note_widget returns validation errors\" do"),
            "{body}"
        );
    }

    #[test]
    fn the_query_shapes_read_through_the_port() {
        let read = describe_body(&ctx_for("read-widget"), "Public API");
        assert!(
            read.contains("test \"read_widget returns :not_found for unknown widget\" do"),
            "{read}"
        );
        assert!(
            read.contains("assert {:error, :not_found} = Widget.read_widget(UUID.uuid4())"),
            "{read}"
        );
        let list = describe_body(&ctx_for("list-widgets"), "Public API");
        assert!(
            list.contains("test \"list_widgets lists read models\" do"),
            "{list}"
        );
        assert!(
            list.contains("assert {:ok, data} = Widget.list_widgets(%JSONAPI.Config{})"),
            "{list}"
        );
        assert!(list.contains("assert is_list(data)"), "{list}");
    }

    #[test]
    fn the_describe_check_accepts_the_alternate_spelling() {
        let units = plan("create-widget").units;
        let describe = units
            .iter()
            .find(|u| u.id.label() == "describe Public API")
            .expect("the describe");
        let existing = crate::elixir::ElixirFile::parse(
            "defmodule T do\n  describe \"Public API - create_widget\" do\n  end\nend\n",
        );
        assert!((describe.check)(&existing));
    }

    #[test]
    fn the_create_operation_comes_from_the_citizen_itself() {
        let ctx = ctx_for("edit-widget");
        let (name, params) = create_operation(&ctx).expect("the citizen declares a create");
        assert_eq!(name, "create_widget");
        assert_eq!(
            params,
            "%{title: \"Vaulting Table\", slug: \"sample-slug-#{UUID.uuid4()}\"}"
        );
    }
}
