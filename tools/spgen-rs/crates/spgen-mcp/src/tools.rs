//! The five read-only tools. Each answers a question the CLI answers too
//! — one truth, two faces. Everything the tools need about the
//! repository is a parameter (`repo_root`), defaulting to the server's
//! cwd walk; a client that manages several checkouts passes it per call.

use serde_json::{Value, json};
use std::path::PathBuf;

pub fn list() -> Value {
    let tools = vec![
        tool(
            "spgen_capabilities",
            "What spgen can generate: by language (elixir|typescript), suites and generators with the exact binding call and port status. Read-only.",
            json!({
                "type": "object",
                "properties": {
                    "target": {"type": "string", "enum": ["elixir", "typescript"], "description": "limit to one language"},
                    "repo_root": {"type": "string"}
                }
            }),
        ),
        tool(
            "spgen_validate",
            "Is the domain model complete enough to generate? The generators' own contracts (descriptions, declared operations, fixture examples, reference closure). Writes nothing, generates nothing. Answers with findings per element.",
            json!({
                "type": "object",
                "properties": {
                    "targets": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "directories or element addresses (esdm:, *.esdm.yaml, kind.name, bare name); empty checks the whole model"
                    },
                    "repo_root": {"type": "string"},
                    "model": {"type": "string", "description": "model root relative to repo_root, default docs/domain-model"}
                }
            }),
        ),
        tool(
            "spgen_man",
            "The manual page of one generator or artifact, rendered as plain text: name, synopsis, the call an operator types, the description, the options, the suites it belongs to. Ambiguous names need target.",
            json!({
                "type": "object",
                "properties": {
                    "generator": {"type": "string"},
                    "target": {"type": "string", "enum": ["elixir", "typescript"], "description": "needed where a name exists in both languages, such as schema"}
                },
                "required": ["generator"]
            }),
        ),
        tool(
            "spgen_arch_location",
            "Where the generated code of a generator+element lives: repo-relative path (or directory) per file role. The same templates the generators write from.",
            json!({
                "type": "object",
                "properties": {
                    "generator": {"type": "string"},
                    "element": {"type": "string", "description": "esdm: reference, *.esdm.yaml, kind.name, or bare name"},
                    "target": {"type": "string", "enum": ["elixir", "typescript"]},
                    "subdomain": {"type": "string"},
                    "composite": {"type": "string"},
                    "constituent": {"type": "string"},
                    "repo_root": {"type": "string"},
                    "model": {"type": "string"}
                },
                "required": ["generator", "element"]
            }),
        ),
        tool(
            "spgen_arch_name",
            "What the generated code is named for a generator+element: modules, changesets, schema names, fixture functions — derived by the architecture's naming rules, same parameters as the generator.",
            json!({
                "type": "object",
                "properties": {
                    "generator": {"type": "string"},
                    "element": {"type": "string"},
                    "target": {"type": "string", "enum": ["elixir", "typescript"]},
                    "subdomain": {"type": "string"},
                    "composite": {"type": "string"},
                    "constituent": {"type": "string"},
                    "repo_root": {"type": "string"},
                    "model": {"type": "string"}
                },
                "required": ["generator", "element"]
            }),
        ),
    ];
    json!({"tools": tools})
}

fn tool(name: &str, description: &str, input_schema: Value) -> Value {
    json!({
        "name": name,
        "description": description,
        "inputSchema": input_schema,
        "annotations": {"readOnlyHint": true, "destructiveHint": false, "idempotentHint": true}
    })
}

pub fn call(params: &Value) -> Result<Value, (i64, String)> {
    let name = params
        .get("name")
        .and_then(Value::as_str)
        .ok_or((-32602, "tools/call needs a name".to_string()))?;
    let args = params.get("arguments").cloned().unwrap_or(json!({}));
    let outcome = match name {
        "spgen_capabilities" => capabilities(&args),
        "spgen_validate" => validate(&args),
        "spgen_man" => man(&args),
        "spgen_arch_location" => arch("location", &args),
        "spgen_arch_name" => arch("name", &args),
        other => {
            return Err((-32602, format!("unknown tool: {other}")));
        }
    };
    Ok(match outcome {
        Ok(result) => result,
        Err(message) => tool_error(message),
    })
}

fn repo_root(args: &Value) -> PathBuf {
    match args.get("repo_root").and_then(Value::as_str) {
        Some(root) => PathBuf::from(root),
        None => spgen_elixir::engine::find_root(
            &std::env::current_dir().unwrap_or_else(|_| PathBuf::from(".")),
        ),
    }
}

fn text_with_json(text: String, value: Value) -> Value {
    json!({
        "content": [{"type": "text", "text": text}],
        "structuredContent": value
    })
}

fn tool_error(message: String) -> Value {
    json!({
        "content": [{"type": "text", "text": message}],
        "isError": true
    })
}

type Outcome = Result<Value, String>;

fn capabilities(args: &Value) -> Outcome {
    let target = args
        .get("target")
        .and_then(Value::as_str)
        .map(str::to_string);
    let caps = spgen::capabilities::build();
    let text = caps.render(target.as_deref());
    Ok(text_with_json(text, caps.to_json(target.as_deref())))
}

fn validate(args: &Value) -> Outcome {
    let targets: Vec<String> = args
        .get("targets")
        .and_then(Value::as_array)
        .map(|list| {
            list.iter()
                .filter_map(Value::as_str)
                .map(str::to_string)
                .collect()
        })
        .unwrap_or_default();
    let root = repo_root(args);
    let model = args
        .get("model")
        .and_then(Value::as_str)
        .map(str::to_string);
    let report = spgen::validate::run(&spgen::validate::Options {
        targets,
        repo_root: Some(root.clone()),
        model,
        cwd: root,
    })?;
    let text = report.render().join("\n");
    Ok(text_with_json(
        text,
        serde_json::to_value(&report).expect("report is serializable"),
    ))
}

fn man(args: &Value) -> Outcome {
    let generator = args
        .get("generator")
        .and_then(Value::as_str)
        .ok_or("spgen_man needs a generator")?;
    let target = args.get("target").and_then(Value::as_str);
    let page = spgen::man::page_text(Some(generator), target)?;
    Ok(json!({
        "content": [{"type": "text", "text": page}]
    }))
}

fn arch(question: &str, args: &Value) -> Outcome {
    let string_field = |name: &str| args.get(name).and_then(Value::as_str).map(str::to_string);
    let root = repo_root(args);
    let query = spgen::arch::Query {
        generator: string_field("generator").ok_or("arch needs a generator")?,
        element: string_field("element").ok_or("arch needs an element")?,
        target: string_field("target"),
        subdomain: string_field("subdomain"),
        composite: string_field("composite"),
        constituent: string_field("constituent"),
        repo_root: root.clone(),
        model: string_field("model").map(PathBuf::from),
    };
    let answers = spgen::arch::answer(question, &query, &root)?;
    let text = answers
        .iter()
        .map(|(k, v)| format!("{k}: {v}"))
        .collect::<Vec<_>>()
        .join("\n");
    let map: Value = answers
        .iter()
        .map(|(k, v)| (k.clone(), Value::String(v.clone())))
        .collect::<serde_json::Map<_, _>>()
        .into();
    Ok(text_with_json(text, map))
}
