//! `spgen validate` — the model-completeness engine, the port of
//! `SpGen.Check`. The questions are the generators' own contracts read
//! back against the model: prose slots, declared operations (completeness
//! and integrity), fixture examples, and — whole-model only — the closed
//! world of the fixture graph. Generates nothing, writes nothing.

use std::path::{Path, PathBuf};

use serde::Serialize;
use spgen_model::Model;
use spgen_model::annotations::{
    EFFECT_PREFIX, OPERATION_KEY, OPERATIONS, QUERY_OPERATIONS, annotations, declared_effects,
};
use spgen_model::fixtures::{examples_of, referenced_keys, validate as validate_examples};
use spgen_model::{Element, ElementKind};

use spgen_elixir::context::{Context, ContextOptions};
use spgen_elixir::engine::find_root;

#[derive(Serialize)]
pub struct Finding {
    pub file: String,
    pub element: String,
    pub message: String,
}

#[derive(Serialize)]
pub struct Report {
    pub complete: bool,
    pub findings: Vec<Finding>,
    pub whole_model: bool,
}

pub struct Options {
    pub targets: Vec<String>,
    pub repo_root: Option<PathBuf>,
    pub model: Option<String>,
    pub cwd: PathBuf,
}

pub fn run(opts: &Options) -> Result<Report, String> {
    let repo_root = opts
        .repo_root
        .clone()
        .unwrap_or_else(|| find_root(&opts.cwd));
    let model_rel = opts.model.as_deref().unwrap_or("docs/domain-model");
    let model_root = repo_root.join(model_rel);
    let model = Model::load(&model_root);

    let (elements, whole) = targets(&model, &opts.targets, &model_root)?;
    let mut findings: Vec<Finding> = Vec::new();
    for element in &elements {
        findings.extend(element_findings(&model, element, &repo_root));
    }
    if whole {
        findings.extend(unresolved_references(&model, &repo_root));
    }
    Ok(Report {
        complete: findings.is_empty(),
        findings,
        whole_model: whole,
    })
}

fn targets(
    model: &Model,
    args: &[String],
    model_root: &Path,
) -> Result<(Vec<Element>, bool), String> {
    if args.is_empty() {
        return Ok((model.elements.clone(), true));
    }
    let mut found: Vec<Element> = Vec::new();
    for arg in args {
        if Path::new(arg).is_dir() {
            let sub = Model::load(Path::new(arg));
            found.extend(sub.elements);
            continue;
        }
        match model.resolve(arg, &[]) {
            Ok(element) => {
                if !found.iter().any(|e| e.address == element.address) {
                    found.push(element);
                }
            }
            Err(error) => return Err(format!("{arg}: {error}")),
        }
    }
    let _ = model_root;
    Ok((found, false))
}

fn element_findings(model: &Model, element: &Element, repo_root: &Path) -> Vec<Finding> {
    let mut out = prose_findings(element);
    out.extend(fixture_findings(model, element));
    out.extend(operation_findings(model, element));
    out.into_iter()
        .map(|f| Finding {
            file: relativize(&f.file, repo_root),
            element: f.element,
            message: relativize(&f.message, repo_root),
        })
        .collect()
}

fn relativize(text: &str, repo_root: &Path) -> String {
    let prefix = format!("{}/", repo_root.display());
    text.replace(prefix.as_str(), "")
}

fn finding(element: &Element, message: String) -> Finding {
    Finding {
        file: element.source.display().to_string(),
        element: element.address.clone(),
        message,
    }
}

// --------------------------------------------------------------------- prose

fn prose_findings(element: &Element) -> Vec<Finding> {
    if !matches!(
        element.kind,
        ElementKind::Command | ElementKind::Event | ElementKind::Query
    ) {
        return Vec::new();
    }
    match element.description() {
        Some(d) if !d.is_empty() => Vec::new(),
        _ => vec![finding(
            element,
            "no description — generated docs and operation summaries would materialize as TODO markers"
                .to_string(),
        )],
    }
}

// ------------------------------------------------------- declared operations

fn spgen_keys(element: &Element) -> Vec<String> {
    let ann = annotations(element);
    let mut keys: Vec<String> = ann
        .as_object()
        .map(|map| {
            map.keys()
                .filter(|k| k.as_str() == OPERATION_KEY || k.starts_with(EFFECT_PREFIX))
                .cloned()
                .collect()
        })
        .unwrap_or_default();
    keys.sort();
    keys
}

fn misplaced(keys: &[String], element: &Element, note: Option<&str>) -> Vec<Finding> {
    if keys.is_empty() {
        return Vec::new();
    }
    let names = keys.join(", ");
    let kind = ElementKind::as_str(&element.kind);
    let message = match note {
        Some(note) => format!(
            "{OPERATION_KEY} annotations belong elsewhere — found {names} on a {kind}; {note}"
        ),
        None => format!("{OPERATION_KEY} annotations belong elsewhere — found {names} on a {kind}"),
    };
    vec![finding(element, message)]
}

fn operation_findings(model: &Model, element: &Element) -> Vec<Finding> {
    let ann = annotations(element);
    match element.kind {
        ElementKind::ReadModel => read_model_ledger(model, element, &ann),
        ElementKind::Command => {
            let prefixed: Vec<String> = spgen_keys(element)
                .into_iter()
                .filter(|k| k != OPERATION_KEY)
                .collect();
            let mut out = command_operation(element, &ann);
            out.extend(misplaced(
                &prefixed,
                element,
                Some(&format!(
                    "commands declare a bare {OPERATION_KEY}, never {EFFECT_PREFIX}<event>"
                )),
            ));
            out
        }
        ElementKind::Query => {
            let prefixed: Vec<String> = spgen_keys(element)
                .into_iter()
                .filter(|k| k != OPERATION_KEY)
                .collect();
            let mut out = query_operation(element, &ann);
            out.extend(misplaced(
                &prefixed,
                element,
                Some(&format!(
                    "queries declare a bare {OPERATION_KEY} (read|collection), never a per-event key"
                )),
            ));
            out
        }
        ElementKind::Event => {
            // events carry no operations — their read model decides
            misplaced(
                &spgen_keys(element),
                element,
                Some("read models declare event effects"),
            )
        }
        _ => misplaced(&spgen_keys(element), element, None),
    }
}

fn command_operation(element: &Element, ann: &serde_json::Value) -> Vec<Finding> {
    match ann.get(OPERATION_KEY) {
        Some(v) if v.as_str().is_some_and(|s| OPERATIONS.contains(&s)) => Vec::new(),
        Some(other) => vec![finding(
            element,
            format!("{OPERATION_KEY}: {other} is not create|update|delete|none"),
        )],
        None => vec![finding(
            element,
            format!(
                "no metadata.annotations.{OPERATION_KEY} (create|update|delete|none) — generation must not guess what {} does",
                element.name
            ),
        )],
    }
}

fn query_operation(element: &Element, ann: &serde_json::Value) -> Vec<Finding> {
    match ann.get(OPERATION_KEY) {
        None => Vec::new(),
        Some(v) if v.as_str().is_some_and(|s| QUERY_OPERATIONS.contains(&s)) => {
            operation_agreement(element, v.as_str().unwrap())
        }
        Some(other) => vec![finding(
            element,
            format!("{OPERATION_KEY}: {other} is not read|collection"),
        )],
    }
}

fn operation_agreement(element: &Element, declared: &str) -> Vec<Finding> {
    let Some(type_) = element
        .doc
        .get("result")
        .and_then(|r| r.get("type"))
        .and_then(|t| t.as_str())
    else {
        return Vec::new();
    };
    let array = type_ == "array";
    let collection = declared == "collection";
    if array == collection {
        Vec::new()
    } else {
        vec![finding(
            element,
            format!(
                "{OPERATION_KEY}: {declared} contradicts result.type: {type_} — a collection reads an array"
            ),
        )]
    }
}

fn read_model_ledger(model: &Model, element: &Element, ann: &serde_json::Value) -> Vec<Finding> {
    let effects = declared_effects(element);
    let projections: Vec<serde_json::Value> = element
        .doc
        .get("projections")
        .and_then(|p| p.as_array())
        .cloned()
        .unwrap_or_default();
    let projected: Vec<String> = projections
        .iter()
        .filter_map(|p| p.get("event").and_then(|e| e.as_str()).map(str::to_string))
        .collect();

    let mut out = Vec::new();
    for event in &projected {
        out.extend(ledger_entry(element, &effects, event));
    }
    for (event, value) in &effects {
        if !projected.contains(event) {
            out.extend(orphan_entry(model, element, event, value));
        }
    }
    if ann.get(OPERATION_KEY).is_some() {
        out.push(finding(
            element,
            format!(
                "a read model decides per event — use {EFFECT_PREFIX}<event> keys, not a bare {OPERATION_KEY}"
            ),
        ));
    }
    out
}

fn ledger_entry(
    element: &Element,
    effects: &[(String, Option<String>)],
    event: &str,
) -> Vec<Finding> {
    match effects.iter().find(|(e, _)| e == event) {
        None => vec![finding(
            element,
            format!("projection of {event} has no {EFFECT_PREFIX}{event} decision"),
        )],
        Some((_, Some(v))) if v == "none" => vec![finding(
            element,
            format!("{EFFECT_PREFIX}{event}: none, but the read model projects {event}"),
        )],
        Some((_, None)) => vec![finding(
            element,
            format!("{EFFECT_PREFIX}{event} has a value outside create|update|delete|none"),
        )],
        Some(_) => Vec::new(),
    }
}

fn orphan_entry(
    model: &Model,
    element: &Element,
    event: &str,
    value: &Option<String>,
) -> Vec<Finding> {
    let known_event = model
        .events_of(&element.name)
        .iter()
        .any(|e| e.name == event);
    if !matches!(value, Some(v) if v == "none") {
        let v = value.clone().unwrap_or_else(|| "invalid".to_string());
        return vec![finding(
            element,
            format!(
                "{EFFECT_PREFIX}{event}: {v} declares materialization, but the read model has no projection of {event}"
            ),
        )];
    }
    if !known_event {
        return vec![finding(
            element,
            format!(
                "{EFFECT_PREFIX}{event} names no event of aggregate {}",
                element.name
            ),
        )];
    }
    Vec::new()
}

// ------------------------------------------------------------------ fixtures

fn fixture_findings(model: &Model, element: &Element) -> Vec<Finding> {
    if element.kind != ElementKind::ReadModel || examples_of(element).is_empty() {
        return Vec::new();
    }
    let ctx = Context::build(
        model,
        element,
        &ContextOptions {
            operation: None,
            subdomain: None,
            composite: None,
            constituent: None,
            repo_root: PathBuf::new(),
        },
    );
    let Ok(ctx) = ctx else {
        return vec![finding(
            element,
            "cannot infer location from the model layout — fixture keys cannot be checked"
                .to_string(),
        )];
    };
    let plural = spgen_model::Name::parse(&ctx.constituent).render_plural(spgen_model::Case::Snake);
    match validate_examples(element, &ctx.composite, &plural) {
        Ok(_) => Vec::new(),
        Err(messages) => messages.into_iter().map(|m| finding(element, m)).collect(),
    }
}

fn unresolved_references(model: &Model, repo_root: &Path) -> Vec<Finding> {
    let defined: Vec<String> = model
        .elements
        .iter()
        .filter(|e| e.kind == ElementKind::ReadModel)
        .flat_map(defined_keys)
        .collect();
    let mut out = Vec::new();
    for element in model
        .elements
        .iter()
        .filter(|e| e.kind == ElementKind::ReadModel)
    {
        for key in referenced_keys(element) {
            if !defined.contains(&key) {
                out.push(Finding {
                    file: relativize(&element.source.display().to_string(), repo_root),
                    element: element.address.clone(),
                    message: format!("references fixture key {key:?}, which no read model defines"),
                });
            }
        }
    }
    out
}

fn defined_keys(element: &Element) -> Vec<String> {
    examples_of(element)
        .iter()
        .filter_map(|e| e.get("id").and_then(|i| i.as_str()).map(str::to_string))
        .filter(|k| spgen_model::fixtures::fixture_key(k))
        .collect()
}

impl Report {
    pub fn render(&self) -> Vec<String> {
        if self.complete {
            return vec!["spgen validate: model complete — nothing to fix".to_string()];
        }
        let mut lines: Vec<String> = self
            .findings
            .iter()
            .map(|f| format!("{}: {}: {}", f.file, f.element, f.message))
            .collect();
        lines.push(String::new());
        lines.push(format!(
            "spgen validate: {} finding(s) — fix the model, then generate",
            self.findings.len()
        ));
        lines
    }
}
