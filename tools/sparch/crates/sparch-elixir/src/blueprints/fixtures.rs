use sparch_model::ElementKind;

use crate::blueprints::read_model::ReadModel;
use crate::context::{Context, FixtureFn};
use crate::plan::{Blueprint, ClosureScope, Dependency, FilePlan};

const PATH: &str =
    "services/api/test/support/<_subdomain>/<composite>/fixtures/<domain_object>s.ex";
const MODULE: &str = "Sportipedia.TestSupport.<Subdomain>.<Composite>.<DomainObject>Fixtures";
const READ_MODEL_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel";

pub struct Fixtures;

impl Fixtures {
    pub fn module_template() -> &'static str {
        MODULE
    }

    pub fn path_template() -> &'static str {
        PATH
    }

    pub fn module_name(ctx: &Context) -> String {
        ctx.render_or_panic(MODULE)
    }

    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(PATH)
    }

    fn plural(ctx: &Context) -> String {
        ctx.render_or_panic("<domain_object>s")
    }

    fn gate_reason(ctx: &Context) -> String {
        format!(
            "the {} read model does not exist (sparch read_model)",
            ctx.constituent
        )
    }
}

impl Blueprint for Fixtures {
    fn name(&self) -> &'static str {
        "fixtures"
    }

    fn description(&self) -> Option<&'static str> {
        Some("Generates a read model's test-support fixtures and factory functions")
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::ReadModel]
    }

    fn closure_scope(&self) -> ClosureScope {
        ClosureScope::None
    }

    fn dependencies(&self, ctx: &Context) -> Vec<Dependency> {
        vec![Dependency {
            blueprint_name: "read_model",
            element: ctx.element.clone(),
        }]
    }

    fn validate(&self, ctx: &Context) -> Result<(), Vec<String>> {
        match crate::context::fixture_functions(
            &ctx.element,
            &ctx.composite,
            &Fixtures::plural(ctx),
        ) {
            Ok(_) => Ok(()),
            Err(messages) => Err(messages),
        }
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(PATH, "fixture functions per example")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        if sparch_model::fixtures::examples_of(&ctx.element).is_empty() {
            return Vec::new();
        }
        vec![FilePlan {
            path: ctx.render_or_panic(PATH),
            module: Some(ctx.render_or_panic(MODULE)),
            units: Vec::new(),
            scaffold: Some(render_source(ctx)),
            format: true,
            unit_created: false,
            requires_describe: false,
            projection: true,
            gate: vec![(ReadModel::module_file(ctx), Fixtures::gate_reason(ctx))],
        }]
    }
}

fn render_source(ctx: &Context) -> String {
    let specs =
        crate::context::fixture_functions(&ctx.element, &ctx.composite, &Fixtures::plural(ctx))
            .unwrap_or_else(|messages| {
                panic!(
                    "fixture examples violate the contract:\n{}",
                    messages.join("\n")
                )
            });
    let rm = ctx.render_or_panic(READ_MODEL_MODULE);
    let local = rm.rsplit('.').next().unwrap_or_default().to_string();

    let mut out = header(ctx, &rm);
    for spec in &specs {
        out.push_str(&fixture_function(spec, &local));
    }
    out.push_str(&aggregate_function(&specs, &local, ctx));
    out.push_str("end\n");
    out
}

fn header(ctx: &Context, rm: &str) -> String {
    format!(
        "defmodule {} do\n  @moduledoc \"\"\"\n  Test fixtures for the {} read model — generated from\n  `{}` by `mix sp.gen.test_support {}`.\n\n  The model's `schema.examples` are the source of truth: this file is a\n  projection and is rewritten whole on every run. Declare fixtures in the\n  domain model, not here.\n\n  Ids materialize as `UUID.uuid5(:dns, \"<composite>:<read-model>:<mnemonic>\")`,\n  so one mnemonic names one thing in every environment forever.\n  \"\"\"\n\n  alias {rm}\n",
        ctx.render_or_panic(MODULE),
        ctx.constituent,
        element_file(ctx),
        element_address(ctx),
    )
}

fn fixture_function(spec: &FixtureFn, local: &str) -> String {
    let attrs = spec
        .attrs
        .iter()
        .map(|(name, source)| format!("      {name}: {source}"))
        .collect::<Vec<_>>()
        .join(",\n");
    format!(
        "\n  @doc \"The `{}` fixture.\"\n  @spec {}() :: {}.t()\n  def {} do\n    %{}{{\n{}\n    }}\n  end\n",
        spec.key, spec.fname, local, spec.fname, local, attrs
    )
}

fn aggregate_function(specs: &[FixtureFn], local: &str, ctx: &Context) -> String {
    let names = specs
        .iter()
        .map(|spec| format!("{}()", spec.fname))
        .collect::<Vec<_>>()
        .join(", ");
    format!(
        "\n  @doc \"All {} fixtures, in model order.\"\n  @spec {}() :: [{}.t()]\n  def {}, do: [{names}]\n",
        ctx.constituent,
        Fixtures::plural(ctx),
        local,
        Fixtures::plural(ctx),
    )
}

fn element_address(ctx: &Context) -> String {
    format!(
        "{}.{}",
        ElementKind::as_str(&ctx.element.kind),
        ctx.element.name
    )
}

fn element_file(ctx: &Context) -> String {
    let source = ctx.element.source.as_path();
    match source.strip_prefix(ctx.repo_root.as_path()) {
        Ok(relative) => relative.display().to_string(),
        Err(_) => source.display().to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::{ContextOptions, fixture_functions};
    use sparch_model::Element;
    use std::path::PathBuf;

    fn read_model(doc: serde_json::Value) -> Element {
        let mut head = serde_json::json!({
            "apiVersion": "schema.esdm.io/core/v1",
            "kind": "read-model",
            "name": "widget",
        });
        for (key, value) in doc.as_object().expect("object doc") {
            head[key.clone()] = value.clone();
        }
        Element {
            kind: ElementKind::ReadModel,
            name: "widget".into(),
            scope: vec![
                ("domain".into(), "sport".into()),
                ("bounded-context".into(), "sport".into()),
            ],
            doc: head,
            source: PathBuf::from(
                "docs/domain-model/catalog/equipment/read-model.widget.esdm.yaml",
            ),
            address: "esdm:domain=sport/bounded-context=sport/read-model=widget".into(),
        }
    }

    fn schema_properties() -> serde_json::Value {
        serde_json::json!({
            "id": { "type": "string", "format": "uuid" },
            "title": { "type": "string" },
            "slug": { "type": "string" },
            "coach_id": { "type": "string", "format": "uuid" },
        })
    }

    #[test]
    fn a_clean_read_model_yields_specs_in_canonical_field_order() {
        let element = read_model(serde_json::json!({
            "schema": {
                "properties": schema_properties(),
                "required": ["id", "title", "slug"],
                "examples": [
                    {
                        "id": "equipment:widget:classic-widget",
                        "title": "Classic Widget",
                        "slug": "classic-widget",
                        "coach_id": "equipment:coach:head-coach",
                    },
                    {
                        "id": "equipment:widget:gadget-2000",
                        "title": "Gadget 2000",
                        "slug": "gadget-2000",
                    }
                ]
            }
        }));
        let specs = fixture_functions(&element, "equipment", "widgets").expect("valid");
        assert_eq!(
            specs.iter().map(|s| s.fname.clone()).collect::<Vec<_>>(),
            vec!["classic_widget", "gadget_2000"]
        );
        let attrs = &specs[0].attrs;
        assert_eq!(
            attrs.iter().map(|(n, _)| n.clone()).collect::<Vec<_>>(),
            vec!["id", "title", "slug", "coach_id"]
        );
        assert_eq!(
            attrs[0].1,
            "UUID.uuid5(:dns, \"equipment:widget:classic-widget\")"
        );
        assert_eq!(attrs[1].1, "\"Classic Widget\"");
        assert_eq!(
            attrs[3].1,
            "UUID.uuid5(:dns, \"equipment:coach:head-coach\")"
        );
    }

    #[test]
    fn field_order_follows_fields_id_required_in_order_optional_alphabetical() {
        let element = read_model(serde_json::json!({
            "schema": {
                "properties": {
                    "title": { "type": "string" },
                    "coach_id": { "type": "string", "format": "uuid" },
                    "id": { "type": "string", "format": "uuid" },
                    "slug": { "type": "string" },
                },
                "required": ["id", "title", "slug"],
                "examples": [
                    {
                        "slug": "x",
                        "coach_id": "equipment:coach:head-coach",
                        "title": "T",
                        "id": "equipment:widget:x",
                    }
                ]
            }
        }));
        let specs = fixture_functions(&element, "equipment", "widgets").expect("valid");
        assert_eq!(
            specs[0]
                .attrs
                .iter()
                .map(|(n, _)| n.clone())
                .collect::<Vec<_>>(),
            vec!["id", "title", "slug", "coach_id"]
        );
    }

    #[test]
    fn every_violation_is_reported_not_just_the_first() {
        let element = read_model(serde_json::json!({
            "schema": {
                "properties": schema_properties(),
                "required": ["id", "title", "slug"],
                "examples": [
                    {
                        "id": "catalog:widget:else",
                        "title": "Très mal",
                        "ghost": "here",
                        "coach_id": "just-a-word-without-colons",
                    }
                ]
            }
        }));
        let errors = fixture_functions(&element, "equipment", "widgets").unwrap_err();
        let text = errors.join("\n");
        assert!(text.contains("carries \"ghost\""), "{text}");
        assert!(
            text.contains("missing required property \"slug\""),
            "{text}"
        );
        assert!(
            text.contains("names \"catalog\"/\"widget\", but this read model lives in \"equipment\"/\"widget\""),
            "{text}"
        );
        assert!(text.contains("neither a fixture key nor a UUID"), "{text}");
        assert!(
            text.contains("would shadow an Elixir keyword"),
            "the keyword guard rides with the other findings: {text}"
        );
    }

    #[test]
    fn an_example_with_no_id_cannot_name_itself() {
        let element = read_model(serde_json::json!({
            "schema": {
                "properties": schema_properties(),
                "required": ["id"],
                "examples": [{ "title": "Homeless" }]
            }
        }));
        let errors = fixture_functions(&element, "equipment", "widgets").unwrap_err();
        assert!(
            errors.iter().any(|m| m.contains("carries no id")),
            "{errors:?}"
        );
    }

    #[test]
    fn a_mnemonic_that_shadows_an_elixir_keyword_is_refused() {
        let element = read_model(serde_json::json!({
            "schema": {
                "properties": schema_properties(),
                "required": [],
                "examples": [{ "id": "equipment:widget:else" }]
            }
        }));
        let errors = fixture_functions(&element, "equipment", "widgets").unwrap_err();
        assert_eq!(errors.len(), 1, "{errors:?}");
        assert!(
            errors[0].contains("would shadow an Elixir keyword — rename the mnemonic"),
            "{}",
            errors[0]
        );
    }

    #[test]
    fn a_mnemonic_naming_the_aggregate_function_collides() {
        let element = read_model(serde_json::json!({
            "schema": {
                "properties": schema_properties(),
                "required": [],
                "examples": [{ "id": "equipment:widget:widgets" }]
            }
        }));
        let errors = fixture_functions(&element, "equipment", "widgets").unwrap_err();
        assert_eq!(errors.len(), 1, "{errors:?}");
        assert!(
            errors[0].contains("colliding with the aggregate function of the same file"),
            "{}",
            errors[0]
        );
    }

    #[test]
    fn the_same_example_declared_twice_is_refused() {
        let element = read_model(serde_json::json!({
            "schema": {
                "properties": schema_properties(),
                "required": [],
                "examples": [
                    { "id": "equipment:widget:gadget-2000" },
                    { "id": "equipment:widget:gadget-2000" },
                ]
            }
        }));
        let errors = fixture_functions(&element, "equipment", "widgets").unwrap_err();
        assert_eq!(errors.len(), 1, "{errors:?}");
        assert!(errors[0].contains("gadget_2000/0"), "{}", errors[0]);
    }

    #[test]
    fn a_read_model_without_examples_validates_to_an_empty_spec_list() {
        let element = read_model(serde_json::json!({
            "schema": { "properties": schema_properties() }
        }));
        assert!(
            fixture_functions(&element, "equipment", "widgets")
                .expect("valid")
                .is_empty()
        );
    }

    #[test]
    fn every_message_names_the_model_file_that_carries_the_violation() {
        let element = read_model(serde_json::json!({
            "schema": {
                "properties": schema_properties(),
                "required": [],
                "examples": [{ "id": "equipment:widget:else" }]
            }
        }));
        let errors = fixture_functions(&element, "equipment", "widgets").unwrap_err();
        assert!(
            errors[0]
                .starts_with("docs/domain-model/catalog/equipment/read-model.widget.esdm.yaml: "),
            "{}",
            errors[0]
        );
    }

    fn ctx_for(name: &str) -> Context {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = sparch_model::Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model
            .resolve(name, &[ElementKind::ReadModel])
            .expect("fixture read model");
        Context::build(
            &model,
            &element,
            &ContextOptions {
                repo_root: root.canonicalize().unwrap(),
                ..Default::default()
            },
        )
        .expect("context builds")
    }

    #[test]
    fn the_projection_plan_names_its_file_module_and_gate() {
        let plan = Fixtures.plans(&ctx_for("widget")).remove(0);
        assert!(plan.projection);
        assert_eq!(
            plan.path,
            "services/api/test/support/catalog/equipment/fixtures/widgets.ex"
        );
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.TestSupport.Catalog.Equipment.WidgetFixtures")
        );
        assert_eq!(
            plan.gate,
            vec![(
                "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex".to_string(),
                "the widget read model does not exist (sparch read_model)".to_string(),
            )]
        );
        assert_eq!(
            Fixtures::module_file(&ctx_for("widget")),
            "services/api/test/support/catalog/equipment/fixtures/widgets.ex"
        );
    }

    #[test]
    fn the_projection_renders_the_whole_file_from_the_model() {
        let plan = Fixtures.plans(&ctx_for("widget")).remove(0);
        let rendered = plan.scaffold.expect("a projection renders its file");
        assert!(
            rendered.starts_with(
                "defmodule Sportipedia.TestSupport.Catalog.Equipment.WidgetFixtures do\n"
            ),
            "{rendered}"
        );
        assert!(
            rendered.contains(
                "read-model.widget.esdm.yaml` by `mix sp.gen.test_support read-model.widget`."
            ),
            "{rendered}"
        );
        assert!(rendered.contains("  @doc \"The `equipment:widget:classic-widget` fixture.\""));
        assert!(rendered.contains("  @spec classic_widget() :: WidgetReadModel.t()"));
        assert!(
            rendered.contains("      id: UUID.uuid5(:dns, \"equipment:widget:classic-widget\"),")
        );
        assert!(rendered.contains("      label: \"classic\","));
        assert!(rendered.contains("  @doc \"The `equipment:widget:gadget-2000` fixture.\""));
        assert!(
            rendered.contains("  @doc \"All widget fixtures, in model order.\""),
            "{rendered}"
        );
        assert!(rendered.contains("  def widgets, do: [classic_widget(), gadget_2000()]"));
        assert!(
            rendered.ends_with("  def widgets, do: [classic_widget(), gadget_2000()]\nend\n"),
            "the render ends at the module's end: {rendered}"
        );
    }

    #[test]
    fn a_read_model_without_examples_generates_nothing() {
        let bare = read_model(serde_json::json!({
            "schema": { "properties": schema_properties() }
        }));
        let ctx = ctx_for("widget").with_element(&bare);
        assert!(Fixtures.plans(&ctx).is_empty());
    }

    #[test]
    fn the_model_gate_refuses_unrenderable_examples_before_any_write() {
        let bad = read_model(serde_json::json!({
            "schema": {
                "properties": schema_properties(),
                "required": [],
                "examples": [{ "id": "equipment:widget:else" }]
            }
        }));
        let ctx = ctx_for("widget").with_element(&bad);
        let errors = Fixtures.validate(&ctx).unwrap_err();
        assert!(
            errors[0].contains("would shadow an Elixir keyword"),
            "{errors:?}"
        );
    }

    #[test]
    fn the_blueprint_arrives_from_the_read_model_and_never_sweeps() {
        assert_eq!(Fixtures.name(), "fixtures");
        assert_eq!(Fixtures.source_kinds(), vec![ElementKind::ReadModel]);
        assert_eq!(Fixtures.closure_scope(), ClosureScope::None);
        let ctx = ctx_for("widget");
        let deps = Fixtures.dependencies(&ctx);
        assert_eq!(deps.len(), 1);
        assert_eq!(deps[0].blueprint_name, "read_model");
        assert_eq!(deps[0].element.name, "widget");
    }
}
