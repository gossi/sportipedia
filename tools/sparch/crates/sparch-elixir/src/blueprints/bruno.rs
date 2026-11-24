use std::path::Path;

use serde_json::{Map, Value};
use sparch_model::ElementKind;

use crate::blueprints::controller::Controller;
use crate::context::{Context, Operation};
use crate::plan::{Actor, Blueprint, FilePlan};
use crate::templates;

const REQUEST_PATH: &str = "bruno/<Subdomain>/<Composite>/<Constituent>/<Operation Title>.yml";
const SAMPLE_ID: &str = "d290f1ee-6c54-4b01-90e6-d701748f0851";

pub struct Bruno;

impl Bruno {
    pub fn request_path(ctx: &Context) -> String {
        let mut slots = sparch_model::placeholders::Slots::new();
        slots.insert("Operation Title".to_string(), operation_title(ctx));
        ctx.render_or_panic_full(
            REQUEST_PATH,
            &sparch_model::placeholders::Vars::new(),
            &slots,
        )
    }
}

impl Blueprint for Bruno {
    fn name(&self) -> &'static str {
        "bruno"
    }

    fn description(&self) -> Option<&'static str> {
        Some("Generates the Bruno API-request documentation for an operation")
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command, ElementKind::Query]
    }

    fn actor(&self) -> Actor {
        Actor::Web
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(REQUEST_PATH, "request docs per operation")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        vec![request_plan(ctx)]
    }
}

fn request_plan(ctx: &Context) -> FilePlan {
    let path = Bruno::request_path(ctx);
    let mut plan = FilePlan::new(path.clone(), None, Vec::new());
    plan.scaffold = Some(request_scaffold(ctx, &path));
    plan.format = false;
    plan.unit_created = false;
    plan
}

fn request_scaffold(ctx: &Context, path: &str) -> String {
    let route = route(ctx);
    format!(
        "info:\n  name: {}\n  type: http\n  seq: {}\n\nhttp:\n{}\n\nsettings:\n  encodeUrl: true\n  timeout: 0\n  followRedirects: true\n  maxRedirects: 5\n{}\n",
        operation_title(ctx),
        request_seq(ctx, path),
        http_block(ctx, &route),
        examples_block(ctx)
    )
    .trim_end()
    .to_string()
        + "\n"
}

fn http_block(ctx: &Context, route: &str) -> String {
    let method = method(ctx);
    format!(
        "  method: {method}\n  url: \"{{{{apiUrl}}}}{route}\"\n{}  auth: inherit",
        request_block(ctx)
    )
}

fn request_block(ctx: &Context) -> String {
    match &ctx.element.kind {
        ElementKind::Command => {
            let body = pad_lines(&body_json(ctx, &scenario_data(ctx)), 6);
            format!("  body:\n    type: json\n    data: |-\n{body}\n")
        }
        ElementKind::Query => {
            if ctx.collection() {
                String::new()
            } else {
                format!(
                    "  params:\n    - name: {}\n      value: {SAMPLE_ID}\n      type: path\n",
                    ctx.read_param()
                )
            }
        }
        _ => String::new(),
    }
}

pub fn body_json(ctx: &Context, data: &Map<String, Value>) -> String {
    let mut inner = vec![format!("    \"type\": \"{}\"", ctx.constituent)];
    let carries_id = ctx.element.kind == ElementKind::Command
        && (matches!(
            ctx.operation,
            Some(Operation::Update) | Some(Operation::Delete)
        ) || (ctx.operation == Some(Operation::None)
            && ctx.fields.iter().any(|f| f.name == "id")));
    if carries_id {
        let id = match data.get("id") {
            Some(value) => to_string_value(value),
            None => SAMPLE_ID.to_string(),
        };
        inner.push(format!("    \"id\": \"{id}\""));
    }
    let attrs: Vec<&crate::context::Befield> = ctx
        .fields
        .iter()
        .filter(|f| !f.internal && f.name != "id")
        .collect();
    if attrs.is_empty() {
        return wrap(&inner);
    }
    let attr_lines = attrs
        .iter()
        .map(|f| format!("      \"{}\": {}", f.name, json_str(&value(data, &f.name))))
        .collect::<Vec<_>>()
        .join(",\n");
    let mut lines = inner;
    lines.push(format!("    \"attributes\": {{\n{attr_lines}\n    }}"));
    wrap(&lines)
}

fn wrap(lines: &[String]) -> String {
    format!("{{\n  \"data\": {{\n{}\n  }}\n}}", lines.join(",\n"))
}

fn value(data: &Map<String, Value>, name: &str) -> Value {
    match data.get(name) {
        Some(Value::Null) => Value::String(format!("sample-{name}")),
        Some(Value::Bool(false)) => Value::String(format!("sample-{name}")),
        Some(found) => found.clone(),
        None => Value::String(format!("sample-{name}")),
    }
}

fn json_str(value: &Value) -> String {
    match value {
        Value::String(text) => templates::inspect_string(text),
        other => templates::inspect_string(&to_string_value(other)),
    }
}

fn to_string_value(value: &Value) -> String {
    match value {
        Value::String(text) => text.clone(),
        Value::Number(number) => number.to_string(),
        Value::Bool(_) | Value::Null | Value::Array(_) | Value::Object(_) => {
            templates::inspect_value(value)
        }
    }
}

fn scenario_data(ctx: &Context) -> Map<String, Value> {
    match ctx.scenarios.first().and_then(|s| s.get("when")) {
        Some(when) => match when.get("data").and_then(Value::as_object) {
            Some(data) if !data.is_empty() => data.clone(),
            _ => Map::new(),
        },
        None => Map::new(),
    }
}

fn examples_block(ctx: &Context) -> String {
    let fallback = Value::Object({
        let mut map = Map::new();
        map.insert("name".to_string(), Value::String(ctx.element.name.clone()));
        map
    });
    let scenarios: Vec<Value> = if ctx.scenarios.is_empty() {
        vec![fallback]
    } else {
        ctx.scenarios.clone()
    };
    let entries = scenarios
        .iter()
        .map(|scenario| example_entry(ctx, scenario))
        .collect::<Vec<_>>()
        .join("");
    format!("\nexamples:\n{entries}")
}

fn example_entry(ctx: &Context, scenario: &Value) -> String {
    let data: Map<String, Value> = scenario
        .get("when")
        .and_then(|when| when.get("data"))
        .and_then(Value::as_object)
        .cloned()
        .unwrap_or_default();
    let method = method(ctx);
    let request = match &ctx.element.kind {
        ElementKind::Command => {
            let body = pad_lines(&body_json(ctx, &data), 10);
            format!(
                "    request:\n      url: \"{{{{apiUrl}}}}{}\"\n      method: {method}\n      body:\n        type: json\n        data: |-\n{body}\n",
                route(ctx)
            )
        }
        _ => format!(
            "    request:\n      url: \"{{{{apiUrl}}}}{}\"\n      method: {method}\n",
            example_route(ctx, &data)
        ),
    };
    format!(
        "  - name: {}\n{request}",
        example_name(ctx, scenario, &data)
    )
}

fn example_route(ctx: &Context, data: &Map<String, Value>) -> String {
    if ctx.element.kind == ElementKind::Query && !ctx.collection() {
        let param = ctx.read_param();
        let value = match data.get(param.as_str()) {
            Some(found) if !found.is_null() => found.clone(),
            _ => match data.get("id") {
                Some(found) if !found.is_null() => found.clone(),
                _ => Value::String(SAMPLE_ID.to_string()),
            },
        };
        route(ctx).replace(&format!(":{param}"), &to_string_value(&value))
    } else {
        route(ctx)
    }
}

fn example_name(ctx: &Context, scenario: &Value, data: &Map<String, Value>) -> String {
    match data.get("title") {
        Some(title) => format!("{} {}", action_word(ctx), to_string_value(title)),
        None => match scenario.get("description").and_then(Value::as_str) {
            Some(text) => text.to_string(),
            None => capitalize_words(
                scenario
                    .get("name")
                    .and_then(Value::as_str)
                    .unwrap_or_default(),
            ),
        },
    }
}

fn action_word(ctx: &Context) -> String {
    ctx.element
        .name
        .split('-')
        .next()
        .map(capitalize_word)
        .unwrap_or_default()
}

fn pad_lines(text: &str, width: usize) -> String {
    let pad = " ".repeat(width);
    text.split('\n')
        .map(|line| format!("{pad}{line}"))
        .collect::<Vec<_>>()
        .join("\n")
}

fn request_seq(ctx: &Context, path: &str) -> usize {
    let dir = ctx
        .repo_root
        .join(Path::new(path).parent().unwrap_or(Path::new("")));
    let existing: Vec<String> = match std::fs::read_dir(&dir) {
        Ok(entries) if dir.is_dir() => entries
            .filter_map(|entry| entry.ok())
            .map(|entry| entry.file_name().to_string_lossy().to_string())
            .filter(|name| name.ends_with(".yml") && name != "folder.yml")
            .collect(),
        _ => Vec::new(),
    };
    existing.len() + 1
}

fn operation_title(ctx: &Context) -> String {
    capitalize_words(&ctx.element.name)
}

fn capitalize_words(text: &str) -> String {
    text.split('-')
        .map(capitalize_word)
        .collect::<Vec<_>>()
        .join(" ")
}

fn capitalize_word(word: &str) -> String {
    let mut chars = word.chars();
    match chars.next() {
        None => String::new(),
        Some(first) => {
            let rest: String = chars.flat_map(|c| c.to_lowercase()).collect();
            format!("{}{rest}", first.to_uppercase())
        }
    }
}

fn route(ctx: &Context) -> String {
    let base = Controller::collection_path(ctx);
    match &ctx.element.kind {
        ElementKind::Command => format!("{base}/{}", ctx.element.name),
        ElementKind::Query => {
            if ctx.collection() {
                base
            } else {
                format!("{base}/:{}", ctx.read_param())
            }
        }
        _ => base,
    }
}

fn method(ctx: &Context) -> &'static str {
    if ctx.element.kind == ElementKind::Command {
        "POST"
    } else {
        "GET"
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use sparch_model::Model;
    use std::path::PathBuf;

    fn model() -> Model {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        Model::load(&root.canonicalize().expect("fixture corpus"))
    }

    fn ctx_for(name: &str) -> Context {
        let element = model()
            .resolve(name, &Bruno.source_kinds())
            .expect("fixture operation");
        Context::build(&model(), &element, &ContextOptions::default()).expect("context builds")
    }

    fn scaffold(name: &str) -> String {
        let ctx = ctx_for(name);
        let plan = Bruno.plans(&ctx).remove(0);
        plan.scaffold.expect("a request file renders")
    }

    #[test]
    fn the_request_file_lands_in_the_constituent_folder() {
        let ctx = ctx_for("create-widget");
        assert_eq!(
            Bruno::request_path(&ctx),
            "bruno/Catalog/Equipment/Widget/Create Widget.yml"
        );
        let plan = Bruno.plans(&ctx).remove(0);
        assert!(!plan.format, "the YAML artifact is never formatted");
        assert!(!plan.unit_created);
        assert!(plan.module.is_none());
        assert!(plan.units.is_empty());
    }

    #[test]
    fn a_write_request_documents_a_jsonapi_body() {
        let text = scaffold("create-widget");
        assert!(
            text.contains("  url: \"{{apiUrl}}/catalog/equipment/widgets/create-widget\""),
            "{text}"
        );
        assert!(text.contains("  method: POST"), "{text}");
        assert!(
            text.contains("      \"title\": \"Pommel Horse\","),
            "the scenario data leads the attributes:\n{text}"
        );
        assert!(
            !text.contains("\"id\":"),
            "a create body carries no id:\n{text}"
        );
    }

    #[test]
    fn update_and_delete_carry_the_id_and_none_carries_it_when_the_model_does() {
        assert!(scaffold("edit-widget").contains("    \"id\": \"{{ generated }}\","));
        assert!(scaffold("archive-widget").contains(&format!("    \"id\": \"{SAMPLE_ID}\"")));
        let note = scaffold("note-widget");
        assert!(
            note.contains(&format!("    \"id\": \"{SAMPLE_ID}\",")),
            "{note}"
        );
        assert!(note.contains("\"comment\": \"sample-comment\""), "{note}");
    }

    #[test]
    fn a_read_documentsthe_path_parameter_and_a_collection_none() {
        let read = scaffold("read-widget");
        assert!(
            read.contains("  url: \"{{apiUrl}}/catalog/equipment/widgets/:id_or_slug\""),
            "{read}"
        );
        assert!(
            read.contains(&format!("      value: {SAMPLE_ID}\n      type: path")),
            "{read}"
        );
        assert!(
            read.contains("      url: \"{{apiUrl}}/catalog/equipment/widgets/d290f1ee-6c54-4b01-90e6-d701748f0851\""),
            "the example fills the parameter:\n{read}"
        );
        let list = scaffold("list-widgets");
        assert!(!list.contains("params:"), "{list}");
        assert!(!list.contains("body:"), "{list}");
        assert!(list.contains("  method: GET"), "{list}");
    }

    #[test]
    fn examples_name_the_scenario_title_or_the_operation_itself() {
        assert!(
            scaffold("create-widget").contains("  - name: Create Pommel Horse"),
            "the scenario title names the example"
        );
        assert!(
            scaffold("archive-widget").contains("  - name: Archive Widget"),
            "no scenario, so the operation title names it"
        );
    }

    #[test]
    fn seq_counts_the_requests_already_in_the_folder() {
        let root = std::env::temp_dir().join("sparch-elixir-bruno-seq");
        let _ = std::fs::remove_dir_all(&root);
        std::fs::create_dir_all(root.join("bruno/Catalog/Equipment/Widget")).unwrap();
        std::fs::write(
            root.join("bruno/Catalog/Equipment/Widget/folder.yml"),
            "info:\n  name: Widget\n",
        )
        .unwrap();
        let ctx = Context::build(
            &Model::load(
                &PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                    .join("../../fixtures/domain-model")
                    .canonicalize()
                    .unwrap(),
            ),
            &Model::load(
                &PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                    .join("../../fixtures/domain-model")
                    .canonicalize()
                    .unwrap(),
            )
            .resolve("edit-widget", &[ElementKind::Command])
            .unwrap(),
            &ContextOptions {
                repo_root: root.clone(),
                ..Default::default()
            },
        )
        .expect("context builds");
        let path = Bruno::request_path(&ctx);
        assert_eq!(request_seq(&ctx, &path), 1, "folder.yml never counts");
        std::fs::write(
            root.join("bruno/Catalog/Equipment/Widget/Create Widget.yml"),
            "info:\n",
        )
        .unwrap();
        assert_eq!(request_seq(&ctx, &path), 2);
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn the_body_lists_the_visible_fields_in_model_order() {
        let ctx = ctx_for("create-widget");
        let data = scenario_data(&ctx);
        let body = body_json(&ctx, &data);
        assert!(
            body.starts_with("{\n  \"data\": {\n    \"type\": \"widget\",\n    \"attributes\": {\n      \"title\":"),
            "{body}"
        );
        assert!(body.ends_with("\n    }\n  }\n}"), "{body}");
    }
}
