use spgen_model::ElementKind;

use crate::blueprints::view::View;
use crate::context::{Context, Operation};
use crate::elixir::{ElixirFile, Rank};
use crate::plan::{Actor, Blueprint, FilePlan, Placement, Stale, Unit, UnitId};
use crate::templates;

const DIR: &str =
    "services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>/schemas";
const FILE: &str =
    "services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>/schemas/<schema>.ex";
const NS: &str = "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.Schemas";
const VIEW_MODULE: &str =
    "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>View";
const OPEN_API_SCHEMA: &str = "Sportipedia.Support.JSONAPI.OpenApiSchema";

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Which {
    Response,
    CollectionResponse,
    Request,
    QueryParams,
}

pub struct Names {
    pub stem: String,
    pub short: String,
    pub full: String,
    pub title: String,
}

pub struct Schema;

impl Schema {
    pub fn module_file(ctx: &Context, which: Which) -> String {
        ctx.render_or_panic(&format!("{DIR}/{}.ex", Schema::names(ctx, which).stem))
    }

    pub fn whiches(ctx: &Context) -> Vec<Which> {
        match (&ctx.element.kind, ctx.operation) {
            (ElementKind::ReadModel, _) => vec![Which::Response, Which::CollectionResponse],
            (
                ElementKind::Command,
                Some(Operation::Create | Operation::Update | Operation::None),
            ) => {
                vec![Which::Request]
            }
            (ElementKind::Query, _) => {
                if ctx.collection() && declares_parameters(ctx) {
                    vec![Which::QueryParams]
                } else {
                    Vec::new()
                }
            }
            _ => Vec::new(),
        }
    }

    pub fn names(ctx: &Context, which: Which) -> Names {
        let (stem_tpl, module_tpl, title_tpl) = spec(which);
        Names {
            stem: ctx.render_or_panic(stem_tpl),
            short: ctx.render_or_panic(module_tpl),
            full: ctx.render_or_panic(&format!("{NS}.{module_tpl}")),
            title: ctx.render_or_panic(title_tpl),
        }
    }
}

fn declares_parameters(ctx: &Context) -> bool {
    matches!(
        ctx.element.doc.get("parameters"),
        Some(value) if !value.is_null()
    )
}

fn spec(which: Which) -> (&'static str, &'static str, &'static str) {
    match which {
        Which::Response => (
            "<domain_object>_response",
            "<DomainObject>Response",
            "<composite>.<DomainObject>",
        ),
        Which::CollectionResponse => (
            "<domain_object>_collection_response",
            "<DomainObject>CollectionResponse",
            "<composite>.<DomainObject>s",
        ),
        Which::Request => (
            "<_operation>_request",
            "<Command>Request",
            "<composite>.<Command>Request",
        ),
        Which::QueryParams => (
            "<_operation>_query_params",
            "<Operation>QueryParams",
            "<composite>.<Operation>QueryParams",
        ),
    }
}

fn derived_call(which: Which) -> &'static str {
    match which {
        Which::QueryParams => "OpenApiSchema.query_params(",
        _ => "OpenApiSchema.from_view(",
    }
}

impl Blueprint for Schema {
    fn name(&self) -> &'static str {
        "schema"
    }

    fn description(&self) -> Option<&'static str> {
        Some("Generates OpenAPI schemas documenting an endpoint")
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![
            ElementKind::ReadModel,
            ElementKind::Command,
            ElementKind::Query,
        ]
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
        vec![(FILE, "OpenAPI schema per shape")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        Schema::whiches(ctx)
            .into_iter()
            .map(|which| plan(ctx, which))
            .collect()
    }
}

fn plan(ctx: &Context, which: Which) -> FilePlan {
    FilePlan::new(
        Schema::module_file(ctx, which),
        Some(Schema::names(ctx, which).full),
        units(ctx, which),
    )
}

fn moduledoc(ctx: &Context, which: Which) -> String {
    match which {
        Which::Response => format!(
            "OpenAPI schema for documenting {} endpoints.",
            ctx.constituent
        ),
        Which::CollectionResponse => format!(
            "OpenAPI schema for documenting {} collection endpoints.",
            ctx.constituent
        ),
        Which::Request => format!(
            "OpenAPI schema for documenting the {} request parameters.",
            ctx.element.name
        ),
        Which::QueryParams => format!(
            "OpenAPI schema for documenting {} collection query parameters.",
            ctx.element.name
        ),
    }
}

fn body(ctx: &Context, which: Which) -> String {
    let n = Schema::names(ctx, which);
    match which {
        Which::Response | Which::CollectionResponse => response_body(ctx, which, &n),
        Which::Request => request_body(ctx, &n),
        Which::QueryParams => query_params_body(ctx, &n),
    }
    .trim_end()
    .to_string()
}

fn response_body(ctx: &Context, which: Which, n: &Names) -> String {
    let view_short = format!("{}View", Context::pascal(&ctx.constituent));
    let many = if which == Which::CollectionResponse {
        ", many: true"
    } else {
        ""
    };
    let what = if which == Which::Response {
        "response"
    } else {
        "collection response"
    };
    format!(
        "@doc \"\"\"\nReturns the OpenAPI schema for the {} {what}.\n\"\"\"\nOpenApiSpex.schema(\n  OpenApiSchema.from_view({view_short}, title: \"{}\"{many})\n)",
        ctx.constituent, n.title
    )
}

fn request_body(ctx: &Context, n: &Names) -> String {
    let fields: Vec<&crate::context::Befield> = ctx.fields.iter().filter(|f| !f.internal).collect();
    let props = fields
        .iter()
        .map(|f| {
            let nullable = if f.required {
                String::new()
            } else {
                ", nullable: true".to_string()
            };
            let description = match &f.description {
                Some(d) => d.clone(),
                None => format!("The {}", f.name),
            };
            format!(
                "      {}: %OpenApiSpex.Schema{{type: {}{nullable}, description: {}}}",
                f.name,
                openapi_type(f),
                templates::inspect_string(&description)
            )
        })
        .collect::<Vec<_>>()
        .join(",\n");
    let required: Vec<String> = fields
        .iter()
        .filter(|f| f.required)
        .map(|f| format!(":{}", f.name))
        .collect();
    let required_line = if required.is_empty() {
        String::new()
    } else {
        format!(",\n      required: [{}]", required.join(", "))
    };
    format!(
        "@doc \"\"\"\nReturns the OpenAPI schema for the {} request.\n\"\"\"\nOpenApiSpex.schema(%{{\n  title: \"{}\",\n  type: :object,\n  properties: %{{\n{props}\n  }}{required_line}\n}})",
        ctx.element.name, n.title
    )
}

fn query_params_body(ctx: &Context, n: &Names) -> String {
    let view_short = format!("{}View", Context::pascal(&ctx.constituent));
    let mut options = vec![format!(
        "      title: {}",
        templates::inspect_string(&n.title)
    )];
    options.extend(filter_option(ctx));
    options.extend(sort_option(ctx));
    options.push(format!("      page: :{}", ctx.page_style().as_str()));
    format!(
        "@doc \"\"\"\nReturns the OpenAPI schema for the {} collection query parameters.\n\"\"\"\nOpenApiSpex.schema(\n  OpenApiSchema.query_params({view_short},\n    {}\n  )\n)",
        ctx.element.name,
        options.join(",\n")
    )
}

fn filter_option(ctx: &Context) -> Vec<String> {
    let filters: Vec<String> = ctx
        .query_parameters()
        .and_then(|p| p.get("filter"))
        .and_then(|f| f.get("properties"))
        .and_then(|v| v.as_object())
        .map(|properties| {
            properties
                .iter()
                .map(|(name, spec)| {
                    let description = spec
                        .get("description")
                        .and_then(|d| d.as_str())
                        .map(str::to_string)
                        .unwrap_or_else(|| {
                            format!("Filter {} by {name} (partial match)", ctx.constituent)
                        });
                    format!("{name}: {}", templates::inspect_string(&description))
                })
                .collect()
        })
        .unwrap_or_default();
    if filters.is_empty() {
        Vec::new()
    } else {
        vec![format!("      filter: [{}]", filters.join(", "))]
    }
}

fn sort_option(ctx: &Context) -> Vec<String> {
    match ctx.sortable_fields() {
        fields if fields.is_empty() => Vec::new(),
        fields => vec![format!("      sort: ~w({})", fields.join(" "))],
    }
}

fn openapi_type(f: &crate::context::Befield) -> &'static str {
    match f.ty.as_str() {
        "string" => ":string",
        "integer" => ":integer",
        "number" => ":number",
        "boolean" => ":boolean",
        _ => ":string",
    }
}

fn units(ctx: &Context, which: Which) -> Vec<Unit> {
    let doc_text = moduledoc(ctx, which);
    let mut units = vec![
        Unit {
            id: UnitId::Moduledoc,
            check: Box::new(|f| f.has_moduledoc()),
            render: Box::new(move || format!("@moduledoc \"\"\"\n{doc_text}\n\"\"\"")),
            place: Placement::Head {
                rank: Rank::Moduledoc,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        },
        Unit {
            id: UnitId::Require("OpenApiSpex".to_string()),
            check: Box::new(|f| f.has_require("OpenApiSpex")),
            render: Box::new(|| "require OpenApiSpex".to_string()),
            place: Placement::Head {
                rank: Rank::Require,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        },
    ];
    units.extend(alias_units(ctx, which));
    units.push(body_unit(ctx, which));
    units
}

fn alias_units(ctx: &Context, which: Which) -> Vec<Unit> {
    if !is_derived(which) {
        return Vec::new();
    }
    let derived = derived_call(which);
    vec![
        alias_unit(ctx.render_or_panic(VIEW_MODULE), derived, view_gate(ctx)),
        alias_unit(OPEN_API_SCHEMA.to_string(), derived, Vec::new()),
    ]
}

fn alias_unit(module: String, derived: &str, requires: Vec<(String, String)>) -> Unit {
    let check_module = module.clone();
    let derived_check = derived.to_string();
    let render = format!("alias {module}");
    Unit {
        id: UnitId::Alias(module.clone()),
        check: Box::new(move |f| f.has_alias(&check_module) || transcribed(f, &derived_check)),
        render: Box::new(move || render.clone()),
        requires,
        place: Placement::Head {
            rank: Rank::Alias,
            alias_sort_key: Some(module),
        },
        stale: None,
    }
}

fn body_unit(ctx: &Context, which: Which) -> Unit {
    let render = body(ctx, which);
    let requires = if is_derived(which) {
        view_gate(ctx)
    } else {
        Vec::new()
    };
    let stale: Stale = Some(Box::new(move |file| stale_derivation(file, which)));
    Unit {
        id: UnitId::AtomId("schema_body".to_string()),
        check: Box::new(move |f| derived_body_present(f, which)),
        render: Box::new(move || render.clone()),
        place: Placement::BodyEnd,
        requires,
        stale,
    }
}

fn view_gate(ctx: &Context) -> Vec<(String, String)> {
    vec![(
        View::module_file(ctx),
        "view not generated (spgen view)".to_string(),
    )]
}

fn is_derived(which: Which) -> bool {
    matches!(
        which,
        Which::Response | Which::CollectionResponse | Which::QueryParams
    )
}

fn derived_body_present(file: &ElixirFile, which: Which) -> bool {
    file.text().contains("OpenApiSpex.schema(")
        && (!is_derived(which) || file.text().contains(derived_call(which)))
}

fn stale_derivation(file: &ElixirFile, which: Which) -> Vec<String> {
    let derived = derived_call(which);
    let text = file.text();
    if !is_derived(which) || !text.contains("OpenApiSpex.schema(") || text.contains(derived) {
        Vec::new()
    } else {
        vec![format!(
            "the schema transcribes what `{derived}` derives — call the builder"
        )]
    }
}

fn transcribed(file: &ElixirFile, derived: &str) -> bool {
    file.text().contains("OpenApiSpex.schema(") && !file.text().contains(derived)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use spgen_model::Model;
    use std::path::PathBuf;

    fn ctx_for(name: &str) -> Context {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model
            .resolve(name, &Schema.source_kinds())
            .expect("fixture element");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn plan_for(name: &str, which: Which) -> FilePlan {
        let ctx = ctx_for(name);
        Schema::whiches(&ctx)
            .into_iter()
            .position(|w| w == which)
            .map(|i| Schema.plans(&ctx).remove(i))
            .expect("element generates this schema role")
    }

    #[test]
    fn whiches_follow_the_element_kind_and_the_declaration() {
        assert_eq!(
            Schema::whiches(&ctx_for("widget")),
            vec![Which::Response, Which::CollectionResponse]
        );
        assert_eq!(
            Schema::whiches(&ctx_for("create-widget")),
            vec![Which::Request]
        );
        assert_eq!(
            Schema::whiches(&ctx_for("note-widget")),
            vec![Which::Request]
        );
        assert!(Schema::whiches(&ctx_for("archive-widget")).is_empty());
        assert_eq!(
            Schema::whiches(&ctx_for("list-widgets")),
            vec![Which::QueryParams]
        );
        assert!(Schema::whiches(&ctx_for("read-widget")).is_empty());
    }

    #[test]
    fn names_paths_and_modules_mirror_the_oracle() {
        let ctx = ctx_for("widget");
        let n = Schema::names(&ctx, Which::CollectionResponse);
        assert_eq!(n.stem, "widget_collection_response");
        assert_eq!(n.short, "WidgetCollectionResponse");
        assert_eq!(
            n.full,
            "SportipediaWeb.Catalog.Equipment.Widget.Schemas.WidgetCollectionResponse"
        );
        assert_eq!(n.title, "equipment.Widgets");
        assert_eq!(
            Schema::module_file(&ctx, Which::CollectionResponse),
            "services/api/lib/sportipedia_web/catalog/equipment/widget/schemas/widget_collection_response.ex"
        );
        let request = Schema::names(&ctx_for("create-widget"), Which::Request);
        assert_eq!(request.stem, "create_widget_request");
        assert_eq!(request.title, "equipment.CreateWidgetRequest");
        let params = Schema::names(&ctx_for("list-widgets"), Which::QueryParams);
        assert_eq!(params.stem, "list_widgets_query_params");
        assert_eq!(params.short, "ListWidgetsQueryParams");
    }

    #[test]
    fn the_response_units_are_moduledoc_require_aliases_body() {
        let labels: Vec<String> = plan_for("widget", Which::Response)
            .units
            .iter()
            .map(|u| u.id.label())
            .collect();
        assert_eq!(
            labels,
            vec![
                "moduledoc",
                "require OpenApiSpex",
                "alias SportipediaWeb.Catalog.Equipment.Widget.WidgetView",
                "alias Sportipedia.Support.JSONAPI.OpenApiSchema",
                "schema_body",
            ]
        );
    }

    #[test]
    fn the_request_shape_carries_no_aliases_and_no_gate() {
        let plan = plan_for("create-widget", Which::Request);
        let labels: Vec<String> = plan.units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            labels,
            vec!["moduledoc", "require OpenApiSpex", "schema_body"]
        );
        for unit in &plan.units {
            assert!(
                unit.requires.is_empty(),
                "{} gates on nothing",
                unit.id.label()
            );
        }
    }

    #[test]
    fn the_rendered_bodies_derive_from_the_view_and_the_model() {
        let units = plan_for("widget", Which::Response).units;
        let body = render(&units, "schema_body");
        assert_eq!(
            body,
            "@doc \"\"\"\nReturns the OpenAPI schema for the widget response.\n\"\"\"\nOpenApiSpex.schema(\n  OpenApiSchema.from_view(WidgetView, title: \"equipment.Widget\")\n)"
        );
        assert_eq!(
            render(
                &plan_for("widget", Which::CollectionResponse).units,
                "moduledoc"
            ),
            "@moduledoc \"\"\"\nOpenAPI schema for documenting widget collection endpoints.\n\"\"\""
        );

        let request = render(
            &plan_for("create-widget", Which::Request).units,
            "schema_body",
        );
        assert_eq!(
            request,
            "@doc \"\"\"\nReturns the OpenAPI schema for the create-widget request.\n\"\"\"\nOpenApiSpex.schema(%{\n  title: \"equipment.CreateWidgetRequest\",\n  type: :object,\n  properties: %{\n      title: %OpenApiSpex.Schema{type: :string, description: \"Name of the widget\"},\n      slug: %OpenApiSpex.Schema{type: :string, description: \"URL-friendly unique identifier\"},\n      coachId: %OpenApiSpex.Schema{type: :string, nullable: true, description: \"Owning coach (optional, mutually exclusive with teamId)\"},\n      description: %OpenApiSpex.Schema{type: :string, nullable: true, description: \"Optional description\"},\n      label: %OpenApiSpex.Schema{type: :string, nullable: true, description: \"Short label shown in lists\"},\n      teamId: %OpenApiSpex.Schema{type: :string, nullable: true, description: \"Owning team (optional, mutually exclusive with coachId)\"}\n  },\n      required: [:title, :slug]\n})"
        );

        let params = render(
            &plan_for("list-widgets", Which::QueryParams).units,
            "schema_body",
        );
        assert_eq!(
            params,
            "@doc \"\"\"\nReturns the OpenAPI schema for the list-widgets collection query parameters.\n\"\"\"\nOpenApiSpex.schema(\n  OpenApiSchema.query_params(WidgetView,\n          title: \"equipment.ListWidgetsQueryParams\",\n      filter: [title: \"Filter widgets by title (partial match)\"],\n      sort: ~w(title slug),\n      page: :numbered\n  )\n)"
        );
    }

    #[test]
    fn the_derived_units_wait_for_the_view() {
        let units = plan_for("widget", Which::Response).units;
        let find = |label: &str| units.iter().find(|u| u.id.label() == label).expect(label);
        let gate = vec![(
            "services/api/lib/sportipedia_web/catalog/equipment/widget/widget_view.ex".to_string(),
            "view not generated (spgen view)".to_string(),
        )];
        assert_eq!(
            find("alias SportipediaWeb.Catalog.Equipment.Widget.WidgetView").requires,
            gate
        );
        assert_eq!(find("schema_body").requires, gate);
        assert!(
            find("alias Sportipedia.Support.JSONAPI.OpenApiSchema")
                .requires
                .is_empty()
        );
    }

    #[test]
    fn a_derived_body_is_present_a_transcription_is_stale_never_appended() {
        let derived = "defmodule S do\n  OpenApiSpex.schema(\n    OpenApiSchema.from_view(WidgetView, title: \"equipment.Widget\")\n  )\nend\n";
        let transcribed_text = "defmodule S do\n  OpenApiSpex.schema(%{\n    title: \"equipment.Widget\",\n    type: :object\n  })\nend\n";
        let units = plan_for("widget", Which::Response).units;
        let body = units
            .iter()
            .find(|u| u.id.label() == "schema_body")
            .expect("body");

        let file = ElixirFile::parse(derived);
        assert!((body.check)(&file));
        assert!(
            body.stale
                .as_ref()
                .expect("a derived body carries a stale check")(&file)
            .is_empty()
        );

        let file = ElixirFile::parse(transcribed_text);
        assert!(
            !(body.check)(&file),
            "a transcription reads as missing so it reaches stale"
        );
        let details = body
            .stale
            .as_ref()
            .expect("a derived body carries a stale check")(&file);
        assert_eq!(
            details,
            vec![
                "the schema transcribes what `OpenApiSchema.from_view(` derives — call the builder"
            ]
        );

        let empty = ElixirFile::parse("defmodule S do\nend\n");
        assert!(!(body.check)(&empty));
        assert!(
            body.stale.as_ref().expect("a stale check")(&empty).is_empty(),
            "absent is placed, not stale"
        );

        let alias = units
            .iter()
            .find(|u| u.id.label() == "alias Sportipedia.Support.JSONAPI.OpenApiSchema")
            .expect("alias");
        assert!((alias.check)(&ElixirFile::parse(transcribed_text)));
    }

    #[test]
    fn the_request_body_is_never_stale_and_the_file_is_unit_created() {
        let plan = plan_for("create-widget", Which::Request);
        assert!(plan.unit_created);
        assert_eq!(
            plan.module.as_deref(),
            Some("SportipediaWeb.Catalog.Equipment.Widget.Schemas.CreateWidgetRequest")
        );
        let body = plan
            .units
            .iter()
            .find(|u| u.id.label() == "schema_body")
            .expect("body");
        let hand = ElixirFile::parse(
            "defmodule S do\n  OpenApiSpex.schema(%{\n    title: \"x\"\n  })\nend\n",
        );
        assert!((body.check)(&hand));
        assert!(body.stale.as_ref().expect("a stale check")(&hand).is_empty());
    }

    fn render(units: &[Unit], label: &str) -> String {
        (units
            .iter()
            .find(|u| u.id.label() == label)
            .unwrap_or_else(|| panic!("no unit {label}"))
            .render)()
    }
}
