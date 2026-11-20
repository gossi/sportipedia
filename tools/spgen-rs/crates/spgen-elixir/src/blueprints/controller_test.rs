use spgen_model::ElementKind;
use spgen_model::fields;

use crate::blueprints::controller::Controller;
use crate::context::{Befield, Context, ContextOptions, Operation};
use crate::elixir::Rank;
use crate::plan::{Blueprint, FilePlan, Placement, Unit, UnitId};
use crate::templates;

const TEST_PATH: &str = "services/api/test/sportipedia_web/<_subdomain>/<composite>/<domain_object>/operations/<_operation>_endpoint_test.exs";
const TEST_MODULE: &str =
    "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<Operation>EndpointTest";

pub struct ControllerTest;

impl Blueprint for ControllerTest {
    fn name(&self) -> &'static str {
        "controller_test"
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command, ElementKind::Query]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(TEST_PATH, "request response endpoint tests")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        let subject = endpoint_subject(ctx);
        let describe = endpoint_describe(ctx).trim_end().to_string();
        let mut plan = FilePlan::new(
            ctx.render_or_panic(TEST_PATH),
            Some(ctx.render_or_panic(TEST_MODULE)),
            vec![
                Unit {
                    id: UnitId::Use("SportipediaWeb.ConnCase".to_string()),
                    check: Box::new(|f| f.has_use("SportipediaWeb.ConnCase")),
                    render: Box::new(|| "use SportipediaWeb.ConnCase".to_string()),
                    place: Placement::Head {
                        rank: Rank::Use,
                        alias_sort_key: None,
                    },
                    requires: Vec::new(),
                    stale: None,
                },
                Unit {
                    id: UnitId::Import("SportipediaWeb.RequestHelpers".to_string()),
                    check: Box::new(|f| f.has_import("SportipediaWeb.RequestHelpers")),
                    render: Box::new(|| "import SportipediaWeb.RequestHelpers".to_string()),
                    place: Placement::Head {
                        rank: Rank::Import,
                        alias_sort_key: None,
                    },
                    requires: Vec::new(),
                    stale: None,
                },
                Unit {
                    id: UnitId::Describe(subject.clone()),
                    check: {
                        let subject = subject.clone();
                        Box::new(move |f| f.has_describe(&subject))
                    },
                    render: Box::new(move || describe.clone()),
                    requires: fixture_seed_gate(ctx),
                    place: Placement::AfterDescribe,
                    stale: None,
                },
            ],
        );
        plan.scaffold = Some(test_scaffold(ctx));
        plan.unit_created = false;
        vec![plan]
    }
}

pub fn endpoint_subject(ctx: &Context) -> String {
    let base = Controller::collection_path(ctx);
    match &ctx.element.kind {
        ElementKind::Command => format!("POST {base}/{}", ctx.element.name),
        ElementKind::Query => {
            if ctx.collection() {
                format!("GET {base} ({})", ctx.element.name)
            } else {
                format!("GET {base}/:{} ({})", ctx.read_param(), ctx.element.name)
            }
        }
        _ => base,
    }
}

fn fixture_seed_gate(ctx: &Context) -> Vec<(String, String)> {
    if ctx.element.kind != ElementKind::Query {
        return Vec::new();
    }
    match ctx.fixture() {
        None => Vec::new(),
        Some(fixture) => vec![
            (
                fixture.file,
                format!(
                    "the {} fixtures do not exist (spgen test_support)",
                    ctx.constituent
                ),
            ),
            (
                fixture.seed_file,
                format!(
                    "the {} test-support factory does not exist (spgen test_support)",
                    ctx.composite
                ),
            ),
        ],
    }
}

fn test_scaffold(ctx: &Context) -> String {
    let aliases: Vec<String> = test_alias_templates(ctx)
        .iter()
        .map(|tpl| format!("  alias {}", ctx.render_or_panic(tpl)))
        .collect();
    format!(
        "defmodule {module} do\n  use SportipediaWeb.ConnCase\n\n  import SportipediaWeb.RequestHelpers\n\n{aliases}\n\n{describe}\nend\n",
        module = ctx.render_or_panic(TEST_MODULE),
        aliases = aliases.join("\n"),
        describe = templates::indent(endpoint_describe(ctx).trim_end(), 2)
    )
}

fn test_alias_templates(ctx: &Context) -> Vec<String> {
    let needs_read_model = ctx.element.kind == ElementKind::Query
        || matches!(
            ctx.operation,
            Some(Operation::Delete) | Some(Operation::None)
        );
    let mut base = vec![Controller::public_api_template().to_string()];
    if needs_read_model {
        base.push(Controller::read_model_template().to_string());
    }
    if ctx.element.kind == ElementKind::Query && ctx.fixtures() {
        base.extend(fixture_seed_aliases(ctx));
    }
    base
}

fn fixture_seed_aliases(ctx: &Context) -> Vec<String> {
    match ctx.fixture() {
        None => Vec::new(),
        Some(fixture) => vec![fixture.seed_module.clone(), fixture.module.clone()],
    }
}

fn endpoint_describe(ctx: &Context) -> String {
    let tests: Vec<String> = endpoint_tests(ctx)
        .into_iter()
        .map(|(name, fun)| fun(ctx, &name))
        .collect();
    format!(
        "describe \"{subject}\" do\n{tests}\nend\n",
        subject = endpoint_subject(ctx),
        tests = templates::indent(&tests.join("\n\n"), 2)
    )
}

type EndpointTest = fn(&Context, &str) -> String;

pub fn endpoint_tests(ctx: &Context) -> Vec<(String, EndpointTest)> {
    let name = ctx.element.name.clone();
    let constituent = ctx.constituent.clone();
    match (&ctx.element.kind, ctx.operation) {
        (ElementKind::Command, Some(Operation::Delete)) => vec![
            (
                format!("{name} returns 204 for a cataloged {constituent}"),
                delete_happy as EndpointTest,
            ),
            ("returns 404 for an unknown id".to_string(), delete_missing),
            (
                "returns 403 when unauthenticated".to_string(),
                unauthenticated,
            ),
        ],
        (ElementKind::Command, Some(Operation::None)) => vec![
            (
                format!("{name} returns 204 for a valid payload"),
                none_happy as EndpointTest,
            ),
            (
                "returns 403 when unauthenticated".to_string(),
                unauthenticated,
            ),
        ],
        (ElementKind::Command, _) => vec![
            (
                format!("{name} returns 200 with the {constituent}"),
                write_happy as EndpointTest,
            ),
            (
                "returns 403 when unauthenticated".to_string(),
                unauthenticated,
            ),
        ],
        (ElementKind::Query, _) => {
            if ctx.collection() {
                vec![(
                    format!("returns 200 with a collection of {constituent}s"),
                    collection_happy as EndpointTest,
                )]
            } else {
                vec![
                    (
                        format!("returns 200 with the {constituent} when found"),
                        read_happy as EndpointTest,
                    ),
                    (
                        format!("returns 404 when the {constituent} does not exist"),
                        read_missing,
                    ),
                ]
            }
        }
        _ => Vec::new(),
    }
}

fn write_happy(ctx: &Context, name: &str) -> String {
    match ctx.operation {
        Some(Operation::Update) => update_happy(ctx, name),
        _ => create_happy(ctx, name),
    }
}

fn create_happy(ctx: &Context, name: &str) -> String {
    format!(
        "test \"{name}\", %{{conn: conn}} do\n  conn =\n    conn\n    |> authenticate_conn()\n    |> api_conn()\n    |> post(\"{route}\", Jason.encode!(jsonapi_body(\"{constituent}\", {data})))\n\n  body = json_response(conn, 200)\n\n  assert jsonapi_type(body) == \"{constituent}\"\nend\n",
        route = endpoint_url(ctx),
        constituent = ctx.constituent,
        data = data_literal(ctx, &ctx.element)
    )
}

fn update_happy(ctx: &Context, name: &str) -> String {
    let base = Controller::collection_path(ctx);
    let create = create_command(ctx).expect("an update addresses a row its create command makes");
    let create_ctx = context_for(ctx, &create);
    let create_route = format!("{base}/{}", create.name);
    format!(
        "test \"{name}\", %{{conn: conn}} do\n  catalog_conn =\n    conn\n    |> authenticate_conn()\n    |> api_conn()\n    |> post(\"{create_route}\", Jason.encode!(jsonapi_body(\"{constituent}\", {create_data})))\n\n  catalog_body = json_response(catalog_conn, 200)\n  id = jsonapi_id(catalog_body)\n\n  conn =\n    conn\n    |> authenticate_conn()\n    |> api_conn()\n    |> post(\"{edit_route}\", Jason.encode!(jsonapi_body(\"{constituent}\", {edit_data}, id)))\n\n  body = json_response(conn, 200)\n\n  assert jsonapi_id(body) == id\nend\n",
        create_route = create_route,
        constituent = ctx.constituent,
        create_data = data_literal(&create_ctx, &create),
        edit_route = endpoint_url(ctx),
        edit_data = data_literal(ctx, &ctx.element)
    )
}

fn unauthenticated(ctx: &Context, name: &str) -> String {
    format!(
        "test \"{name}\", %{{conn: conn}} do\n  conn =\n    conn\n    |> api_conn()\n    |> post(\"{route}\", Jason.encode!(jsonapi_body(\"{constituent}\", %{{}})))\n\n  assert json_response(conn, 403)\nend\n",
        route = endpoint_url(ctx),
        constituent = ctx.constituent
    )
}

fn none_happy(ctx: &Context, name: &str) -> String {
    format!(
        "test \"{name}\", %{{conn: conn}} do\n  conn =\n    conn\n    |> authenticate_conn()\n    |> api_conn()\n    |> post(\"{route}\", Jason.encode!(jsonapi_body(\"{constituent}\", {data})))\n\n  assert conn.status == 204\n  assert conn.resp_body == \"\"\nend\n",
        route = endpoint_url(ctx),
        constituent = ctx.constituent,
        data = data_literal(ctx, &ctx.element)
    )
}

fn delete_happy(ctx: &Context, name: &str) -> String {
    format!(
        "test \"{name}\", %{{conn: conn}} do\n  {{:ok, %{{id: id}}}} = {seed}\n\n  conn =\n    conn\n    |> authenticate_conn()\n    |> api_conn()\n    |> post(\"{route}\", Jason.encode!(jsonapi_body(\"{constituent}\", %{{}}, id)))\n\n  assert conn.status == 204\n  assert conn.resp_body == \"\"\nend\n",
        seed = seed_expr(ctx),
        route = endpoint_url(ctx),
        constituent = ctx.constituent
    )
}

fn delete_missing(ctx: &Context, name: &str) -> String {
    format!(
        "test \"{name}\", %{{conn: conn}} do\n  conn =\n    conn\n    |> authenticate_conn()\n    |> api_conn()\n    |> post(\"{route}\", Jason.encode!(jsonapi_body(\"{constituent}\", %{{}}, UUID.uuid4())))\n\n  assert json_response(conn, 404)\nend\n",
        route = endpoint_url(ctx),
        constituent = ctx.constituent
    )
}

fn read_happy(ctx: &Context, name: &str) -> String {
    format!(
        "test \"{name}\", %{{conn: conn}} do\n{seed}\n\n  conn =\n    conn\n    |> api_conn()\n    |> get(\"{base}/#{{id}}\")\n\n  body = json_response(conn, 200)\n\n  assert jsonapi_id(body) == id\nend\n",
        seed = templates::indent(&seed_block(ctx, "{:ok, %{id: id}}", false), 6),
        base = Controller::collection_path(ctx)
    )
}

fn read_missing(ctx: &Context, name: &str) -> String {
    format!(
        "test \"{name}\", %{{conn: conn}} do\n  conn =\n    conn\n    |> api_conn()\n    |> get(\"{base}/#{{UUID.uuid4()}}\")\n\n  assert json_response(conn, 404)\nend\n",
        base = Controller::collection_path(ctx)
    )
}

fn collection_happy(ctx: &Context, name: &str) -> String {
    format!(
        "test \"{name}\", %{{conn: conn}} do\n{seed}\n\n  conn =\n    conn\n    |> api_conn()\n    |> get(\"{base}\")\n\n  body = json_response(conn, 200)\n\n  assert is_list(body[\"data\"])\nend\n",
        seed = templates::indent(&seed_block(ctx, "{:ok, _}", true), 6),
        base = Controller::collection_path(ctx)
    )
}

fn endpoint_url(ctx: &Context) -> String {
    format!("{}/{}", Controller::collection_path(ctx), ctx.element.name)
}

fn data_literal(ctx: &Context, element: &spgen_model::Element) -> String {
    if let Some(data) = scenario_data(ctx) {
        let parts: Vec<String> = data
            .iter()
            .map(|(key, value)| format!("{key}: {}", templates::inspect_value(value)))
            .collect();
        return format!("%{{{}}}", parts.join(", "));
    }
    let unique = ctx.unique_fields();
    let parts: Vec<String> = fields(element)
        .into_iter()
        .filter(|f| f.required && f.name != "id")
        .map(|f| {
            let field = Befield::from_field(&f);
            let value = if unique.contains(&f.name) {
                format!("\"sample-{}-#{{UUID.uuid4()}}\"", f.name)
            } else {
                templates::sample_value(ctx, &field)
            };
            format!("{}: {value}", f.name)
        })
        .collect();
    if parts.is_empty() {
        "%{}".to_string()
    } else {
        format!("%{{{}}}", parts.join(", "))
    }
}

fn scenario_data(ctx: &Context) -> Option<&serde_json::Map<String, serde_json::Value>> {
    ctx.scenarios
        .first()?
        .get("when")?
        .get("data")?
        .as_object()
        .filter(|data| !data.is_empty())
}

fn seed_block(ctx: &Context, binding: &str, all: bool) -> String {
    match ctx.fixture() {
        None => format!("{binding} = {}", seed_expr(ctx)),
        Some(fixture) if all => format!("{binding} = {}", Context::seed_all_expr(&fixture)),
        Some(fixture) => format!("{binding} = {}", Context::seed_expr(&fixture)),
    }
}

fn seed_expr(ctx: &Context) -> String {
    match create_command(ctx) {
        None => panic!(
            "no create command for {} found to seed tests",
            ctx.constituent
        ),
        Some(cmd) => {
            let create_ctx = context_for(ctx, &cmd);
            let api = Context::pascal(&ctx.constituent);
            let op = cmd.name.replace('-', "_");
            format!("{}.{}({})", api, op, data_literal(&create_ctx, &cmd))
        }
    }
}

fn context_for(ctx: &Context, element: &spgen_model::Element) -> Context {
    Context::build(
        &ctx.model,
        element,
        &ContextOptions {
            repo_root: ctx.repo_root.clone(),
            ..Default::default()
        },
    )
    .expect("the create command builds a context")
}

fn create_command(ctx: &Context) -> Option<spgen_model::Element> {
    ctx.model
        .elements
        .iter()
        .filter(|el| {
            el.kind == ElementKind::Command && el.aggregate_name() == Some(ctx.constituent.as_str())
        })
        .find(|el| el.publishes().iter().any(|event| creates_row(ctx, event)))
        .cloned()
}

fn creates_row(ctx: &Context, event_name: &str) -> bool {
    ctx.effect_for_event(event_name) == Some(Operation::Create)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::blueprints::fixtures::Fixtures;
    use spgen_model::Model;
    use std::path::PathBuf;

    fn ctx_for(name: &str) -> Context {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model
            .resolve(name, &ControllerTest.source_kinds())
            .expect("fixture operation");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn plan_for(name: &str) -> FilePlan {
        ControllerTest.plans(&ctx_for(name)).remove(0)
    }

    #[test]
    fn the_endpoint_test_file_names_the_operation_and_its_module() {
        let plan = plan_for("create-widget");
        assert_eq!(
            plan.path,
            "services/api/test/sportipedia_web/catalog/equipment/widget/operations/create_widget_endpoint_test.exs"
        );
        assert_eq!(
            plan.module.as_deref(),
            Some("SportipediaWeb.Catalog.Equipment.Widget.CreateWidgetEndpointTest")
        );
        assert!(
            !plan.unit_created,
            "the file is created whole from its scaffold"
        );
        let labels: Vec<String> = plan.units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            labels,
            vec![
                "use SportipediaWeb.ConnCase",
                "import SportipediaWeb.RequestHelpers",
                "describe POST /catalog/equipment/widgets/create-widget",
            ]
        );
    }

    #[test]
    fn the_subjects_follow_the_verb_rule() {
        assert_eq!(
            endpoint_subject(&ctx_for("edit-widget")),
            "POST /catalog/equipment/widgets/edit-widget"
        );
        assert_eq!(
            endpoint_subject(&ctx_for("read-widget")),
            "GET /catalog/equipment/widgets/:id_or_slug (read-widget)"
        );
        assert_eq!(
            endpoint_subject(&ctx_for("list-widgets")),
            "GET /catalog/equipment/widgets (list-widgets)"
        );
    }

    #[test]
    fn the_scaffold_carries_the_aliases_the_body_needs() {
        let scaffold = plan_for("create-widget").scaffold.expect("a scaffold");
        assert!(
            scaffold.contains("  alias Sportipedia.Catalog.Equipment.Widget\n"),
            "{scaffold}"
        );
        assert!(
            !scaffold.contains("WidgetReadModel"),
            "a create test dispatches through the public API only:\n{scaffold}"
        );
        assert!(
            scaffold.contains("describe \"POST /catalog/equipment/widgets/create-widget\" do"),
            "{scaffold}"
        );
        let read = plan_for("read-widget").scaffold.expect("a scaffold");
        assert!(read.contains("alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel"));
        assert_eq!(
            Fixtures::module_name(&ctx_for("read-widget")),
            "Sportipedia.TestSupport.Catalog.Equipment.WidgetFixtures"
        );
    }

    #[test]
    fn the_status_matrix_picks_the_tests_per_shape() {
        let names = |kebab: &str| -> Vec<String> {
            endpoint_tests(&ctx_for(kebab))
                .into_iter()
                .map(|(name, _)| name)
                .collect()
        };
        assert_eq!(
            names("archive-widget"),
            vec![
                "archive-widget returns 204 for a cataloged widget",
                "returns 404 for an unknown id",
                "returns 403 when unauthenticated",
            ]
        );
        assert_eq!(
            names("list-widgets"),
            vec!["returns 200 with a collection of widgets"]
        );
        assert_eq!(
            names("read-widget"),
            vec![
                "returns 200 with the widget when found",
                "returns 404 when the widget does not exist",
            ]
        );
    }

    #[test]
    fn the_write_body_is_the_scenario_data_when_the_model_has_one() {
        let ctx = ctx_for("create-widget");
        let literal = data_literal(&ctx, &ctx.element);
        assert_eq!(
            literal,
            "%{label: \"Pommel\", slug: \"pommel-horse\", title: \"Pommel Horse\"}"
        );
    }

    #[test]
    fn the_seed_names_the_fixture_factory_for_reads_and_the_create_command_otherwise() {
        let ctx = ctx_for("read-widget");
        assert_eq!(
            seed_block(&ctx, "{:ok, %{id: id}}", false),
            "{:ok, %{id: id}} = Equipment.new_widget(WidgetFixtures.classic_widget())"
        );
        let list = ctx_for("list-widgets");
        assert_eq!(
            seed_block(&list, "{:ok, _}", true),
            "{:ok, _} = Equipment.new_widgets(WidgetFixtures.widgets())"
        );
        let archive = ctx_for("archive-widget");
        assert_eq!(
            seed_expr(&archive),
            "Widget.create_widget(%{label: \"Pommel\", slug: \"pommel-horse\", title: \"Pommel Horse\"})"
        );
    }

    #[test]
    fn only_a_query_test_waits_for_the_test_support_citizens() {
        assert!(
            fixture_seed_gate(&ctx_for("create-widget")).is_empty(),
            "a command test seeds through the public API"
        );
        let gates = fixture_seed_gate(&ctx_for("read-widget"));
        assert_eq!(gates.len(), 2);
        assert_eq!(
            gates[0].1,
            "the widget fixtures do not exist (spgen test_support)"
        );
        assert_eq!(
            gates[1].1,
            "the equipment test-support factory does not exist (spgen test_support)"
        );
    }
}
