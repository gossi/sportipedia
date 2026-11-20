use sparch_model::ElementKind;

use crate::blueprints::public_api::PublicApi;
use crate::blueprints::read_model::ReadModel;
use crate::blueprints::schema::{Schema, Which};
use crate::blueprints::view::View;
use crate::context::{Context, Operation};
use crate::elixir::Rank;
use crate::plan::{Actor, Blueprint, FilePlan, MacroPredicate, Placement, Unit, UnitId};
use crate::templates;

const PATH: &str = "services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>/<domain_object>_controller.ex";
const MODULE: &str =
    "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Controller";
const PUBLIC_API_MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>";
const VIEW_MODULE: &str =
    "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>View";
const READ_MODEL_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel";
const COLLECTION_RESPONSE: &str = "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.Schemas.<DomainObject>CollectionResponse";
const RESPONSE: &str =
    "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.Schemas.<DomainObject>Response";
const REQUEST: &str =
    "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.Schemas.<Command>Request";
const QUERY_PARAMS: &str =
    "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.Schemas.<Operation>QueryParams";

pub struct Controller;

impl Controller {
    pub fn module_template() -> &'static str {
        MODULE
    }

    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(PATH)
    }

    pub fn public_api_template() -> &'static str {
        PUBLIC_API_MODULE
    }

    pub fn read_model_template() -> &'static str {
        READ_MODEL_MODULE
    }

    pub fn collection_path(ctx: &Context) -> String {
        ctx.render_or_panic("/<-subdomain>/<-composite>/<domain-object>s")
    }

    pub fn route_path(ctx: &Context) -> String {
        match &ctx.element.kind {
            ElementKind::Command => format!("/{}", ctx.element.name),
            ElementKind::Query => {
                if ctx.collection() {
                    "/".to_string()
                } else {
                    format!("/:{}", ctx.read_param())
                }
            }
            _ => "/".to_string(),
        }
    }

    pub fn operation_block(ctx: &Context) -> String {
        let op = ctx.op_snake();
        let api = Context::pascal(&ctx.constituent);
        let header = format!(
            "@doc \"\"\"\nHandles the {} request.\n\"\"\"\n{}\n",
            ctx.element.name,
            operation_spec(ctx)
        );
        format!(
            "{}\n\n@spec {}(Plug.Conn.t(), map()) :: Plug.Conn.t()\ndef {}(conn, _) do\n{}\nend\n",
            header.trim_end(),
            op,
            op,
            templates::indent(action_body(ctx, &op, &api).trim_end(), 2)
        )
    }
}

impl Blueprint for Controller {
    fn name(&self) -> &'static str {
        "controller"
    }

    fn description(&self) -> Option<&'static str> {
        Some("Generates the controller action, endpoint test and route")
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command, ElementKind::Query]
    }

    fn actor(&self) -> Actor {
        Actor::Web
    }

    fn is_fixed(&self) -> bool {
        false
    }

    fn operations(&self) -> Vec<Operation> {
        vec![
            Operation::Create,
            Operation::Update,
            Operation::Delete,
            Operation::None,
            Operation::Read,
            Operation::Collection,
        ]
    }

    fn optional_template(&self) -> bool {
        true
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(PATH, "endpoint action calling the API")]
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
    let mut units = header_units(ctx);
    units.extend(op_alias_units(ctx));
    units.push(operation_unit(ctx));
    units
}

fn header_units(ctx: &Context) -> Vec<Unit> {
    let composite = ctx.composite.clone();
    let bodyguard = bodyguard_plug(ctx).trim_end().to_string();
    let moduledoc = format!(
        "@moduledoc \"\"\"\nHandles HTTP requests for {} operations.\n\"\"\"",
        ctx.constituent
    );
    let mut units = vec![
        Unit {
            id: UnitId::Moduledoc,
            check: Box::new(|f| f.has_moduledoc()),
            render: Box::new(move || moduledoc.clone()),
            place: Placement::Head {
                rank: Rank::Moduledoc,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        },
        use_unit("SportipediaWeb", "use SportipediaWeb, :controller"),
        use_unit(
            "OpenApiSpex.ControllerSpecs",
            "use OpenApiSpex.ControllerSpecs",
        ),
        Unit {
            id: UnitId::Plug("Bodyguard.Plug.Authorize".to_string()),
            check: Box::new(|f| f.has_entry("plug", "Bodyguard.Plug.Authorize")),
            render: Box::new(move || bodyguard.clone()),
            place: Placement::AfterMacro {
                macro_name: "use".into(),
                predicate: MacroPredicate::Any,
                fallback: Box::new(Placement::Head {
                    rank: Rank::Attribute,
                    alias_sort_key: None,
                }),
            },
            requires: Vec::new(),
            stale: None,
        },
    ];
    units.extend(query_parser_unit(ctx));
    units.extend([
        Unit {
            id: UnitId::AtomId("tags".to_string()),
            check: {
                let key = format!("[\"{composite}\"]");
                Box::new(move |f| f.has_entry("tags", &key))
            },
            render: Box::new(move || format!("tags [\"{composite}\"]")),
            place: Placement::AfterMacro {
                macro_name: "plug".into(),
                predicate: MacroPredicate::Any,
                fallback: Box::new(Placement::BodyEnd),
            },
            requires: Vec::new(),
            stale: None,
        },
        alias_unit(
            "OpenApiSpex.Reference".to_string(),
            "alias OpenApiSpex.Reference",
            Vec::new(),
        ),
        alias_unit(
            "SportipediaWeb.System.FallbackController".to_string(),
            "alias SportipediaWeb.System.FallbackController",
            Vec::new(),
        ),
        alias_unit(
            ctx.render_or_panic(PUBLIC_API_MODULE),
            &format!("alias {}", ctx.render_or_panic(PUBLIC_API_MODULE)),
            Vec::new(),
        ),
    ]);
    units
}

fn use_unit(module: &str, text: &str) -> Unit {
    let check_module = module.to_string();
    let render = text.to_string();
    Unit {
        id: UnitId::Use(module.to_string()),
        check: Box::new(move |f| f.has_use(&check_module)),
        render: Box::new(move || render.clone()),
        place: Placement::Head {
            rank: Rank::Use,
            alias_sort_key: None,
        },
        requires: Vec::new(),
        stale: None,
    }
}

fn alias_unit(module: String, text: &str, requires: Vec<(String, String)>) -> Unit {
    let check_module = module.clone();
    let render = text.to_string();
    Unit {
        id: UnitId::Alias(module.clone()),
        check: Box::new(move |f| f.has_alias(&check_module)),
        render: Box::new(move || render.clone()),
        requires,
        place: Placement::Head {
            rank: Rank::Alias,
            alias_sort_key: Some(module),
        },
        stale: None,
    }
}

fn query_parser_unit(ctx: &Context) -> Vec<Unit> {
    if !ctx.collection() {
        return Vec::new();
    }
    let parser = query_parser_plug(ctx).trim_end().to_string();
    vec![Unit {
        id: UnitId::Plug("JSONAPI.QueryParser".to_string()),
        check: Box::new(|f| f.has_entry("plug", "JSONAPI.QueryParser")),
        render: Box::new(move || parser.clone()),
        requires: view_gate(ctx),
        place: Placement::AfterMacro {
            macro_name: "plug".into(),
            predicate: MacroPredicate::Any,
            fallback: Box::new(Placement::Head {
                rank: Rank::Attribute,
                alias_sort_key: None,
            }),
        },
        stale: None,
    }]
}

fn operation_unit(ctx: &Context) -> Unit {
    let op = ctx.op_snake();
    let check_op = op.clone();
    let render = Controller::operation_block(ctx).trim_end().to_string();
    Unit {
        id: UnitId::Operation(op),
        check: Box::new(move |f| f.has_def(&check_op, 2)),
        render: Box::new(move || render.clone()),
        requires: op_gate(ctx),
        place: Placement::BodyEnd,
        stale: None,
    }
}

fn op_alias_units(ctx: &Context) -> Vec<Unit> {
    let op = ctx.op_snake();
    op_aliases(ctx)
        .into_iter()
        .map(|tpl| {
            let module = ctx.render_or_panic(&tpl);
            let check_module = module.clone();
            let check_def = op.clone();
            let render = format!("alias {module}");
            Unit {
                id: UnitId::Alias(module.clone()),
                check: Box::new(move |f| f.has_alias(&check_module) || f.has_def(&check_def, 2)),
                render: Box::new(move || render.clone()),
                requires: alias_gate(ctx, &tpl),
                place: Placement::Head {
                    rank: Rank::Alias,
                    alias_sort_key: Some(module),
                },
                stale: None,
            }
        })
        .collect()
}

fn op_gate(ctx: &Context) -> Vec<(String, String)> {
    let mut gates = vec![(
        PublicApi::module_file(ctx),
        "public API not generated (sparch public_api)".to_string(),
    )];
    if ctx.element.kind == ElementKind::Query && !ctx.collection() {
        gates.push((
            ReadModel::module_file(ctx),
            "read model not generated (sparch read_model)".to_string(),
        ));
    }
    gates
}

fn alias_gate(ctx: &Context, tpl: &str) -> Vec<(String, String)> {
    if tpl == VIEW_MODULE {
        view_gate(ctx)
    } else if tpl == READ_MODEL_MODULE {
        vec![(
            ReadModel::module_file(ctx),
            "read model not generated (sparch read_model)".to_string(),
        )]
    } else if tpl == COLLECTION_RESPONSE {
        schema_gate(ctx, Which::CollectionResponse)
    } else if tpl == RESPONSE {
        schema_gate(ctx, Which::Response)
    } else if tpl == REQUEST {
        schema_gate(ctx, Which::Request)
    } else if tpl == QUERY_PARAMS {
        schema_gate(ctx, Which::QueryParams)
    } else {
        Vec::new()
    }
}

fn schema_gate(ctx: &Context, which: Which) -> Vec<(String, String)> {
    vec![(
        Schema::module_file(ctx, which),
        "schema not generated (sparch schema)".to_string(),
    )]
}

fn view_gate(ctx: &Context) -> Vec<(String, String)> {
    vec![(
        View::module_file(ctx),
        "view not generated (sparch view)".to_string(),
    )]
}

fn op_aliases(ctx: &Context) -> Vec<String> {
    match (&ctx.element.kind, ctx.operation) {
        (ElementKind::Command, Some(Operation::Delete)) => Vec::new(),
        (ElementKind::Command, Some(Operation::None)) => vec![REQUEST.to_string()],
        (ElementKind::Command, _) => vec![
            VIEW_MODULE.to_string(),
            RESPONSE.to_string(),
            REQUEST.to_string(),
        ],
        (ElementKind::Query, _) => {
            if ctx.collection() {
                vec![
                    VIEW_MODULE.to_string(),
                    COLLECTION_RESPONSE.to_string(),
                    QUERY_PARAMS.to_string(),
                ]
            } else {
                vec![
                    VIEW_MODULE.to_string(),
                    READ_MODEL_MODULE.to_string(),
                    RESPONSE.to_string(),
                ]
            }
        }
        _ => Vec::new(),
    }
}

fn bodyguard_plug(ctx: &Context) -> String {
    format!(
        "  plug Bodyguard.Plug.Authorize,\n    policy: {}.Policy,\n    action: {{Phoenix.Controller, :action_name}},\n    user: {{Sportipedia.Auth, :get_user_from_assigns}},\n    fallback: FallbackController\n",
        ctx.render_or_panic(PUBLIC_API_MODULE)
    )
}

fn query_parser_plug(ctx: &Context) -> String {
    if !ctx.collection() {
        return String::new();
    }
    format!(
        "  plug JSONAPI.QueryParser,\n    filter: ~w({}),\n    sort: ~w({}),\n    view: {}View\n",
        ctx.filterable_fields().join(" "),
        ctx.sortable_fields().join(" "),
        Context::pascal(&ctx.constituent)
    )
}

fn operation_spec(ctx: &Context) -> String {
    let op = ctx.op_snake();
    let summary = match ctx.description() {
        Some(text) => text.to_string(),
        None => format!("TODO: describe the {} operation", ctx.element.name),
    };
    let responses = responses(ctx)
        .iter()
        .map(|r| format!("        {r}"))
        .collect::<Vec<_>>()
        .join(",\n");
    format!(
        "operation :{op},\n  summary: \"{summary}\",{}\n  responses: [\n{responses}\n  ]",
        spec_params(ctx)
    )
}

fn spec_params(ctx: &Context) -> String {
    if ctx.element.kind == ElementKind::Command && ctx.operation != Some(Operation::Delete) {
        format!(
            "\n      request_body: {{\"The {} attributes\", \"application/json\", {}Request}},",
            ctx.constituent,
            Context::pascal(&ctx.element.name)
        )
    } else if ctx.element.kind == ElementKind::Query && ctx.collection() {
        format!(
            "\n      parameters: [\n        query: [in: :query, schema: {}QueryParams]\n      ],",
            Context::pascal(&ctx.element.name)
        )
    } else if ctx.element.kind == ElementKind::Query {
        let param = ctx.read_param();
        format!(
            "\n      parameters: [\n        {param}: [in: :path, description: \"The {} {}\", type: :string]\n      ],",
            ctx.constituent,
            param.replace('_', " or ")
        )
    } else {
        String::new()
    }
}

fn responses(ctx: &Context) -> Vec<String> {
    let response = format!("{}Response", Context::pascal(&ctx.constituent));
    match (&ctx.element.kind, ctx.operation) {
        (ElementKind::Command, Some(Operation::Delete)) => vec![
            format!("no_content: \"The {} has been archived\"", ctx.constituent),
            reference("not_found"),
            reference("unauthorized"),
            reference("forbidden"),
        ],
        (ElementKind::Command, Some(Operation::None)) => vec![
            format!(
                "no_content: \"The {} was processed without materialization\"",
                ctx.constituent
            ),
            reference("not_found"),
            reference("unprocessable_entity"),
            reference("unauthorized"),
            reference("forbidden"),
        ],
        (ElementKind::Command, _) => vec![
            format!(
                "ok: {{\"The {}\", \"application/vnd.api+json\", {response}}}",
                ctx.constituent
            ),
            reference("unprocessable_entity"),
            reference("unauthorized"),
            reference("forbidden"),
        ],
        (ElementKind::Query, _) => {
            if ctx.collection() {
                vec![format!(
                    "ok: {{\"{} collection\", \"application/vnd.api+json\", {}CollectionResponse}}",
                    Context::pascal(&ctx.constituent),
                    Context::pascal(&ctx.constituent)
                )]
            } else {
                vec![
                    format!(
                        "ok: {{\"The {}\", \"application/vnd.api+json\", {response}}}",
                        ctx.constituent
                    ),
                    reference("not_found"),
                ]
            }
        }
        _ => Vec::new(),
    }
}

fn reference(name: &str) -> String {
    format!("{name}: %Reference{{\"$ref\": \"#/components/responses/{name}\"}}")
}

fn action_body(ctx: &Context, op: &str, api: &str) -> String {
    let view = format!("{}View", Context::pascal(&ctx.constituent));
    let var = ctx.constituent.clone();
    let body = match (&ctx.element.kind, ctx.operation) {
        (ElementKind::Command, Some(Operation::Delete)) => format!(
            "case {api}.{op}(conn.params[\"id\"]) do\n  :ok ->\n    send_resp(conn, :no_content, \"\")\n\n  {{:error, errors}} ->\n    {{:error, errors}}\nend\n"
        ),
        (ElementKind::Command, Some(Operation::None)) => format!(
            "case {api}.{op}(conn.params) do\n  :ok ->\n    send_resp(conn, :no_content, \"\")\n\n  {{:error, errors}} ->\n    {{:error, errors}}\nend\n"
        ),
        (ElementKind::Command, _) => format!(
            "with {{:ok, {var}}} <- {api}.{op}(conn.params) do\n  conn\n  |> put_view(json: {view})\n  |> render(\"show.json\", %{{data: {var}}})\nend\n"
        ),
        (ElementKind::Query, _) => {
            if ctx.collection() {
                format!(
                    "case {api}.{op}(conn.assigns.jsonapi_query) do\n  {{:ok, data}} ->\n    conn\n    |> put_view(json: {view})\n    |> render(\"index.json\", %{{data: data}})\nend\n"
                )
            } else {
                let rm = format!("{}ReadModel", Context::pascal(&ctx.constituent));
                let param = ctx.read_param();
                format!(
                    "case {api}.{op}(conn.params[\"{param}\"]) do\n  {{:ok, %{rm}{{}} = {var}}} ->\n    conn\n    |> put_view(json: {view})\n    |> render(\"show.json\", %{{data: {var}}})\n\n  {{:error, :not_found}} ->\n    {{:error, :not_found}}\nend\n"
                )
            }
        }
        _ => String::new(),
    };
    body.trim_end().to_string()
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
            .resolve(name, &Controller.source_kinds())
            .expect("fixture operation");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn units_for(name: &str) -> Vec<Unit> {
        Controller.plans(&ctx_for(name)).remove(0).units
    }

    fn render(units: &[Unit], label: &str) -> String {
        (units
            .iter()
            .find(|u| u.id.label() == label)
            .unwrap_or_else(|| panic!("no unit {label}"))
            .render)()
    }

    #[test]
    fn paths_routes_and_the_collection_path_render_as_the_model_expects() {
        let ctx = ctx_for("create-widget");
        assert_eq!(
            Controller::module_file(&ctx),
            "services/api/lib/sportipedia_web/catalog/equipment/widget/widget_controller.ex"
        );
        assert_eq!(
            ctx.render_or_panic(Controller::module_template()),
            "SportipediaWeb.Catalog.Equipment.Widget.WidgetController"
        );
        assert_eq!(
            Controller::collection_path(&ctx),
            "/catalog/equipment/widgets"
        );
        assert_eq!(Controller::route_path(&ctx), "/create-widget");
        assert_eq!(Controller::route_path(&ctx_for("list-widgets")), "/");
        assert_eq!(
            Controller::route_path(&ctx_for("read-widget")),
            "/:id_or_slug"
        );
    }

    #[test]
    fn the_write_units_are_header_then_aliases_then_the_action() {
        let labels: Vec<String> = units_for("create-widget")
            .iter()
            .map(|u| u.id.label())
            .collect();
        assert_eq!(
            labels,
            vec![
                "moduledoc",
                "use SportipediaWeb",
                "use OpenApiSpex.ControllerSpecs",
                "plug Bodyguard.Plug.Authorize",
                "tags",
                "alias OpenApiSpex.Reference",
                "alias SportipediaWeb.System.FallbackController",
                "alias Sportipedia.Catalog.Equipment.Widget",
                "alias SportipediaWeb.Catalog.Equipment.Widget.WidgetView",
                "alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.WidgetResponse",
                "alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.CreateWidgetRequest",
                "operation create_widget",
            ]
        );
    }

    #[test]
    fn a_collection_query_carries_the_parser_and_no_read_model_alias() {
        let units = units_for("list-widgets");
        let labels: Vec<String> = units.iter().map(|u| u.id.label()).collect();
        assert!(labels.contains(&"plug JSONAPI.QueryParser".to_string()));
        assert!(
            labels.contains(
                &"alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.ListWidgetsQueryParams"
                    .to_string()
            )
        );
        assert_eq!(
            render(&units, "plug JSONAPI.QueryParser"),
            "  plug JSONAPI.QueryParser,\n    filter: ~w(title),\n    sort: ~w(title slug),\n    view: WidgetView"
        );
    }

    #[test]
    fn the_action_block_is_the_spec_the_spec_and_the_clause() {
        let units = units_for("create-widget");
        assert_eq!(
            render(&units, "operation create_widget"),
            "@doc \"\"\"\nHandles the create-widget request.\n\"\"\"\noperation :create_widget,\n  summary: \"Catalogs a new widget in the equipment catalog\",\n      request_body: {\"The widget attributes\", \"application/json\", CreateWidgetRequest},\n  responses: [\n        ok: {\"The widget\", \"application/vnd.api+json\", WidgetResponse},\n        unprocessable_entity: %Reference{\"$ref\": \"#/components/responses/unprocessable_entity\"},\n        unauthorized: %Reference{\"$ref\": \"#/components/responses/unauthorized\"},\n        forbidden: %Reference{\"$ref\": \"#/components/responses/forbidden\"}\n  ]\n\n@spec create_widget(Plug.Conn.t(), map()) :: Plug.Conn.t()\ndef create_widget(conn, _) do\n  with {:ok, widget} <- Widget.create_widget(conn.params) do\n    conn\n    |> put_view(json: WidgetView)\n    |> render(\"show.json\", %{data: widget})\n  end\nend"
        );
        assert_eq!(
            render(&units_for("archive-widget"), "operation archive_widget"),
            "@doc \"\"\"\nHandles the archive-widget request.\n\"\"\"\noperation :archive_widget,\n  summary: \"Archives a widget that is no longer used\",\n  responses: [\n        no_content: \"The widget has been archived\",\n        not_found: %Reference{\"$ref\": \"#/components/responses/not_found\"},\n        unauthorized: %Reference{\"$ref\": \"#/components/responses/unauthorized\"},\n        forbidden: %Reference{\"$ref\": \"#/components/responses/forbidden\"}\n  ]\n\n@spec archive_widget(Plug.Conn.t(), map()) :: Plug.Conn.t()\ndef archive_widget(conn, _) do\n  case Widget.archive_widget(conn.params[\"id\"]) do\n    :ok ->\n      send_resp(conn, :no_content, \"\")\n\n    {:error, errors} ->\n      {:error, errors}\n  end\nend"
        );
        assert_eq!(
            render(&units_for("read-widget"), "operation read_widget"),
            "@doc \"\"\"\nHandles the read-widget request.\n\"\"\"\noperation :read_widget,\n  summary: \"Retrieve a single widget by its id or slug\",\n      parameters: [\n        id_or_slug: [in: :path, description: \"The widget id or or or slug\", type: :string]\n      ],\n  responses: [\n        ok: {\"The widget\", \"application/vnd.api+json\", WidgetResponse},\n        not_found: %Reference{\"$ref\": \"#/components/responses/not_found\"}\n  ]\n\n@spec read_widget(Plug.Conn.t(), map()) :: Plug.Conn.t()\ndef read_widget(conn, _) do\n  case Widget.read_widget(conn.params[\"id_or_slug\"]) do\n    {:ok, %WidgetReadModel{} = widget} ->\n      conn\n      |> put_view(json: WidgetView)\n      |> render(\"show.json\", %{data: widget})\n\n    {:error, :not_found} ->\n      {:error, :not_found}\n  end\nend"
        );
    }

    #[test]
    fn every_reference_the_action_names_gates_on_its_own_citizen() {
        let ctx = ctx_for("read-widget");
        let units = Controller.plans(&ctx).remove(0).units;
        let find = |label: &str| units.iter().find(|u| u.id.label() == label).expect("unit");
        let schema =
            "services/api/lib/sportipedia_web/catalog/equipment/widget/schemas/widget_response.ex";
        assert_eq!(
            find("alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.WidgetResponse").requires,
            vec![(
                schema.to_string(),
                "schema not generated (sparch schema)".to_string()
            )]
        );
        assert_eq!(
            find("operation read_widget").requires,
            vec![
                (
                    "services/api/lib/sportipedia/catalog/equipment/widget/public_api.ex"
                        .to_string(),
                    "public API not generated (sparch public_api)".to_string()
                ),
                (
                    "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex"
                        .to_string(),
                    "read model not generated (sparch read_model)".to_string()
                )
            ]
        );
        assert!(
            find("alias Sportipedia.Catalog.Equipment.Widget")
                .requires
                .is_empty()
        );
    }

    #[test]
    fn an_action_makes_its_reference_aliases_present() {
        let text = "defmodule C do\n  def create_widget(conn, _) do\n    :ok\n  end\nend\n";
        let units = units_for("create-widget");
        let find = |label: &str| units.iter().find(|u| u.id.label() == label).expect("unit");
        let request =
            find("alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.CreateWidgetRequest");
        assert!(
            (request.check)(&crate::elixir::ElixirFile::parse(text)),
            "a merged-in action counts as satisfied for every alias it names"
        );
        let empty = crate::elixir::ElixirFile::parse("defmodule C do\nend\n");
        assert!(!(request.check)(&empty));
        assert!(
            !(find("alias Sportipedia.Catalog.Equipment.Widget").check)(&empty),
            "the public API alias is its own fact"
        );
    }
}
