//! `sparch validate` — the model-completeness engine. The questions are
//! the generators' own contracts read
//! back against the model: prose slots, declared operations (completeness
//! and integrity), fixture examples, and — whole-model only — the closed
//! world of the fixture graph. Generates nothing, writes nothing.

use std::path::{Path, PathBuf};

use serde::Serialize;
use sparch_model::fields::{self, RELATION_KEY};
use sparch_model::Model;
use sparch_model::annotations::{
    EFFECT_PREFIX, OPERATION_KEY, OPERATIONS, QUERY_OPERATIONS, annotations, declared_effects,
};
use sparch_model::fixtures::{examples_of, referenced_keys, validate as validate_examples};
use sparch_model::{Case, Element, ElementKind, Name, RelationKind};

use sparch_elixir::context::{Context, ContextOptions};
use sparch_elixir::engine::find_root;

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
        findings.extend(relation_whole_findings(&model));
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
    out.extend(relation_findings(model, element));
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

fn sparch_keys(element: &Element) -> Vec<String> {
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
            let prefixed: Vec<String> = sparch_keys(element)
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
            let prefixed: Vec<String> = sparch_keys(element)
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
                &sparch_keys(element),
                element,
                Some("read models declare event effects"),
            )
        }
        _ => misplaced(&sparch_keys(element), element, None),
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
    let plural =
        sparch_model::Name::parse(&ctx.constituent).render_plural(sparch_model::Case::Snake);
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
        .filter(|k| sparch_model::fixtures::fixture_key(k))
        .collect()
}

// ----------------------------------------------------------------- relations
//
// Integrity checks for `x-esdm-relation`. Only read model properties carry
// meaning here; a keyword on a command or event has none and is ignored,
// never policed. These checks refuse what the generators would otherwise
// have to guess: an unresolvable kind, a property shape that contradicts
// its kind, two sides describing different edges, join storage that
// collides, and command or event id fields that reference nothing.

fn relation_findings(model: &Model, element: &Element) -> Vec<Finding> {
    if element.kind != ElementKind::ReadModel {
        return Vec::new();
    }
    let properties = element
        .doc
        .get("schema")
        .and_then(|s| s.get("properties"))
        .and_then(|p| p.as_object());
    let mut out: Vec<Finding> = Vec::new();
    for f in fields::fields(element) {
        let spec = properties.and_then(|p| p.get(&f.name));
        let Some(relation) = &f.relation else {
            if spec.is_some_and(fields::malformed_relation) {
                out.push(finding(
                    element,
                    format!(
                        "property \"{}\" carries {RELATION_KEY} without a resolvable to and kind; kind must be belongs_to, has_one, has_many or many_to_many, and the field reads as plain data until it does",
                        f.name
                    ),
                ));
            }
            continue;
        };
        out.extend(relation_declaration(element, &f.name, relation, spec));
        let Some(target) = model.find(ElementKind::ReadModel, &relation.to) else {
            out.push(finding(
                element,
                format!(
                    "\"{}\" points to read model \"{}\", which no document defines",
                    f.name, relation.to
                ),
            ));
            continue;
        };
        if let Some(inverse) = &relation.inverse {
            out.extend(relation_pair(model, element, &f.name, relation, &target, inverse));
        }
    }
    out
}

/// What one declaration must state: a subkey valid for its kind, a property
/// shape the kind can render, and a join storage vocabulary that excludes
/// itself.
fn relation_declaration(
    element: &Element,
    name: &str,
    relation: &sparch_model::Relation,
    spec: Option<&serde_json::Value>,
) -> Vec<Finding> {
    let kind = relation.kind.as_str();
    let mut out = Vec::new();
    if relation.column.is_some() && relation.kind != RelationKind::BelongsTo {
        out.push(finding(
            element,
            format!("column on \"{name}\" is only for belongs_to, but its kind is {kind}"),
        ));
    }
    if (relation.join_table.is_some() || relation.join_model.is_some())
        && relation.kind != RelationKind::ManyToMany
    {
        out.push(finding(
            element,
            format!("join_table and join_model on \"{name}\" are only for many_to_many, but its kind is {kind}"),
        ));
    }
    if relation.join_table.is_some() && relation.join_model.is_some() {
        out.push(finding(
            element,
            format!("\"{name}\" declares both join_table and join_model; one link has one storage"),
        ));
    }
    if relation.kind != RelationKind::BelongsTo && relation.inverse.is_none() {
        out.push(finding(
            element,
            format!("{kind} \"{name}\" must bind the far side with inverse"),
        ));
    }
    let shape_ok = match relation.kind {
        RelationKind::BelongsTo | RelationKind::HasOne => is_uuid_scalar(spec),
        RelationKind::HasMany | RelationKind::ManyToMany => is_uuid_array(spec),
    };
    if !shape_ok {
        out.push(finding(
            element,
            match relation.kind {
                RelationKind::HasMany | RelationKind::ManyToMany => format!(
                    "{kind} \"{name}\" is an array of uuids by definition; its schema says otherwise"
                ),
                _ => format!(
                    "{kind} \"{name}\" holds one uuid by definition; its schema says otherwise"
                ),
            },
        ));
    }
    out
}

fn is_uuid_scalar(spec: Option<&serde_json::Value>) -> bool {
    spec.is_some_and(|s| {
        s.get("type").and_then(|t| t.as_str()) == Some("string")
            && s.get("format").and_then(|x| x.as_str()) == Some("uuid")
    })
}

fn is_uuid_array(spec: Option<&serde_json::Value>) -> bool {
    spec.is_some_and(|s| {
        s.get("type").and_then(|t| t.as_str()) == Some("array")
            && s.get("items").is_some_and(|i| {
                i.get("type").and_then(|t| t.as_str()) == Some("string")
                    && i.get("format").and_then(|x| x.as_str()) == Some("uuid")
            })
    })
}

/// Both sides describe one edge, so both statements must agree: the far
/// property exists, pairs kinds across the edge, points back, names this
/// property back, and (for a modeled or named link) stores in the same
/// place.
fn relation_pair(
    model: &Model,
    element: &Element,
    name: &str,
    relation: &sparch_model::Relation,
    target: &Element,
    inverse: &str,
) -> Vec<Finding> {
    let mut out = Vec::new();
    let far_fields = fields::fields(target);
    let Some(far) = far_fields.iter().find(|q| q.name == inverse) else {
        return vec![finding(
            element,
            format!(
                "{} \"{name}\" binds the far side \"{inverse}\" on {}, which does not declare it",
                relation.kind.as_str(),
                target.name
            ),
        )];
    };
    let Some(far_relation) = &far.relation else {
        return vec![finding(
            element,
            format!(
                "{} \"{name}\" binds \"{inverse}\" on {}, but that property is plain data",
                relation.kind.as_str(),
                target.name
            ),
        )];
    };
    let pairs = match relation.kind {
        RelationKind::BelongsTo => matches!(
            far_relation.kind,
            RelationKind::HasOne | RelationKind::HasMany
        ),
        RelationKind::HasOne | RelationKind::HasMany => {
            far_relation.kind == RelationKind::BelongsTo
        }
        RelationKind::ManyToMany => far_relation.kind == RelationKind::ManyToMany,
    };
    if !pairs {
        out.push(finding(
            element,
            format!(
                "{} \"{name}\" pairs with {} \"{}\", but {} declares {}",
                relation.kind.as_str(),
                relation.kind.as_str(),
                inverse,
                target.name,
                far_relation.kind.as_str()
            ),
        ));
    }
    if far_relation.to != element.name {
        out.push(finding(
            element,
            format!(
                "{} \"{name}\" expects \"{inverse}\" on {} to point back here; it points to {}",
                relation.kind.as_str(),
                target.name,
                far_relation.to
            ),
        ));
    }
    if far_relation.inverse.as_deref() != Some(name) {
        out.push(finding(
            element,
            format!(
                "\"{inverse}\" on {} must name this property back with inverse: {name}",
                target.name
            ),
        ));
    }
    if relation.kind == RelationKind::HasOne {
        let edges = far_fields
            .iter()
            .filter(|q| {
                q.relation
                    .as_ref()
                    .is_some_and(|r| r.kind == RelationKind::BelongsTo && r.to == element.name)
            })
            .count();
        if edges != 1 {
            out.push(finding(
                element,
                format!(
                    "has_one \"{name}\" requires exactly one belongs_to to {} on {}, but there are {edges}",
                    element.name, target.name
                ),
            ));
        }
    }
    if relation.kind == RelationKind::ManyToMany
        && far_relation.kind == RelationKind::ManyToMany
        && storage_of(&element.name, relation) != storage_of(&target.name, far_relation)
    {
        out.push(finding(
            element,
            format!(
                "many_to_many \"{name}\" and \"{}\" on {} must name the same join storage",
                far.name, target.name
            ),
        ));
    }
    if let Some(jm) = &relation.join_model {
        let Some(link) = model.find(ElementKind::ReadModel, jm) else {
            out.push(finding(
                element,
                format!("join_model \"{jm}\" of \"{name}\" names no read model"),
            ));
            return out;
        };
        let link_fields = fields::fields(&link);
        let edges: Vec<&sparch_model::Field> = link_fields
            .iter()
            .filter(|q| {
                q.relation
                    .as_ref()
                    .is_some_and(|r| r.kind == RelationKind::BelongsTo)
            })
            .collect();
        let wanted: Vec<String> = vec![element.name.clone(), relation.to.clone()];
        let ok = edges.len() == 2
            && wanted.iter().all(|side| {
                edges
                    .iter()
                    .any(|q| q.relation.as_ref().is_some_and(|r| r.to == *side))
            });
        if !ok {
            out.push(finding(
                element,
                format!(
                    "join_model \"{jm}\" must carry exactly two belongs_to properties, one to {} and one to {}",
                    element.name, relation.to
                ),
            ));
        }
    }
    out
}

/// Where a `many_to_many` keeps its link: the named model, the named
/// table, or the table derived from the pair. The pair's derivation is
/// symmetric, so both sides of one edge compute the same source.
fn storage_of(owner: &str, relation: &sparch_model::Relation) -> String {
    match (&relation.join_model, &relation.join_table) {
        (Some(jm), _) => format!("model:{jm}"),
        (None, Some(jt)) => format!("table:{jt}"),
        (None, None) => format!(
            "table:{}",
            sparch_elixir::blueprints::read_model::derive_join_table(owner, &relation.to)
        ),
    }
}

/// One declaration of a join storage: the pair it links, the read model
/// that declares it, and the property carrying the relation.
type StorageUse = ((String, String), Element, String);

/// Whole-model relation checks: join storage identity across the model,
/// and the correlation that ties command and event id fields to the read
/// model they write.
fn relation_whole_findings(model: &Model) -> Vec<Finding> {
    let mut out = Vec::new();

    // (storage, pair) per declared many_to_many property — one entry per
    // side, so a pair appears twice with the same storage and pair key
    let mut stored: Vec<(String, (String, String), Element, String)> = Vec::new();
    for rm in model.elements.iter().filter(|e| e.kind == ElementKind::ReadModel) {
        for f in fields::fields(rm) {
            let Some(relation) = &f.relation else { continue };
            if relation.kind != RelationKind::ManyToMany {
                continue;
            }
            if model
                .find(ElementKind::ReadModel, &relation.to)
                .is_none()
            {
                continue;
            }
            let storage = match (&relation.join_model, &relation.join_table) {
                (Some(jm), _) => format!("model:{jm}"),
                (None, Some(jt)) => format!("table:{jt}"),
                (None, None) => format!(
                    "table:{}",
                    sparch_elixir::blueprints::read_model::derive_join_table(&rm.name, &relation.to)
                ),
            };
            let pair = {
                let mut sides = [rm.name.clone(), relation.to.clone()];
                sides.sort();
                (sides[0].clone(), sides[1].clone())
            };
            stored.push((storage, pair, rm.clone(), f.name.clone()));
        }
    }

    // a table-named storage may not collide with a read model's own table
    let tables: Vec<String> = model
        .elements
        .iter()
        .filter(|e| e.kind == ElementKind::ReadModel)
        .map(|e| Name::parse(&e.name).render(Case::Snake))
        .collect();
    for (storage, _, rm, property) in &stored {
        if let Some(table) = storage.strip_prefix("table:")
            && tables.contains(&Name::parse(table).render(Case::Snake))
        {
            out.push(finding(
                rm,
                format!(
                    "join table \"{table}\" of \"{property}\" names the table of a read model; spell the edge's storage differently or model the link"
                ),
            ));
        }
    }

    // one storage links one pair; two distinct pairs sharing it is a bug,
    // and one side declaring the same pair's edge twice is the same story
    let mut counts: Vec<(String, Vec<StorageUse>)> = Vec::new();
    for (storage, pair, rm, property) in &stored {
        match counts.iter_mut().find(|(s, _)| s == storage) {
            Some((_, seen)) => seen.push((pair.clone(), rm.clone(), property.clone())),
            None => counts.push((storage.clone(), vec![(pair.clone(), rm.clone(), property.clone())])),
        }
    }
    for (storage, seen) in &counts {
        let mut distinct_pairs: Vec<(String, String)> =
            seen.iter().map(|(p, _, _)| p.clone()).collect();
        distinct_pairs.sort();
        distinct_pairs.dedup();
        if distinct_pairs.len() > 1 {
            for (_, rm, property) in seen {
                out.push(finding(
                    rm,
                    format!(
                        "\"{property}\" shares join storage {storage} with a relation between different read models; give each link its own table or model"
                    ),
                ));
            }
            continue;
        }
        // one pair must reach one storage from each of its two sides;
        // a side declaring it twice collides with its own sibling
        let sides: Vec<String> = seen.iter().map(|(_, rm, _)| rm.name.clone()).collect();
        let mut distinct_sides = sides.clone();
        distinct_sides.sort();
        distinct_sides.dedup();
        if seen.len() > 2 || distinct_sides.len() < sides.len() {
            for (_, rm, property) in seen {
                out.push(finding(
                    rm,
                    format!(
                        "\"{property}\" shares join storage {storage} with another relation of the same pair; two links between one pair need two storages"
                    ),
                ));
            }
        }
    }

    // command and event correlation: an id-suffixed data field must match
    // the read model's relation naming rule or a plain property of it
    for e in model
        .elements
        .iter()
        .filter(|e| matches!(e.kind, ElementKind::Command | ElementKind::Event))
    {
        let Some(rm) = model.read_model_for(e) else {
            continue;
        };
        let rm_fields = fields::fields(&rm);
        for f in fields::fields(e) {
            if f.name == "id" || !fields::has_id_tail(&f.name) {
                continue;
            }
            let matched = rm_fields
                .iter()
                .find(|p| p.relation.is_some() && fields::field_matches_property(&f.name, p));
            if let Some(p) = matched {
                // a modeled link writes rows through its own commands;
                // a parent-side set would fight that owner or silently
                // drop the link's own properties
                if p.relation.as_ref().is_some_and(|r| r.join_model.is_some()) {
                    out.push(finding(
                        e,
                        format!(
                            "data field \"{}\" sets the modeled link \"{}\" of the {} read model; a join_model owns its rows through its own commands and events",
                            f.name, p.name, rm.name
                        ),
                    ));
                }
                continue;
            }
            let plain = rm_fields
                .iter()
                .any(|p| p.relation.is_none() && p.name == f.name);
            if plain {
                continue;
            }
            out.push(finding(
                e,
                format!(
                    "data field \"{}\" carries an id suffix but matches no relation of the {} read model and no plain property either; a relation key plus _id writes a belongs_to, a collection key singularized plus _ids writes a many_to_many set",
                    f.name, rm.name
                ),
            ));
        }
    }
    out
}

impl Report {
    pub fn render(&self) -> Vec<String> {
        if self.complete {
            return vec!["sparch validate: model complete — nothing to fix".to_string()];
        }
        let mut lines: Vec<String> = self
            .findings
            .iter()
            .map(|f| format!("{}: {}: {}", f.file, f.element, f.message))
            .collect();
        lines.push(String::new());
        lines.push(format!(
            "sparch validate: {} finding(s) — fix the model, then generate",
            self.findings.len()
        ));
        lines
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use std::path::PathBuf;

    fn element(kind: &str, name: &str, doc: serde_json::Value) -> Element {
        Element {
            kind: ElementKind::parse(kind),
            name: name.to_string(),
            scope: vec![],
            doc,
            source: PathBuf::from(format!("{}.esdm.yaml", name)),
            address: format!("esdm:read-model={name}"),
        }
    }

    fn read_model(name: &str, properties: serde_json::Value) -> Element {
        element(
            "read-model",
            name,
            json!({ "schema": { "type": "object", "properties": properties } }),
        )
    }

    fn model_of(elements: Vec<Element>) -> Model {
        Model {
            root: PathBuf::from("/model"),
            elements,
        }
    }

    fn relation_messages(model: &Model) -> Vec<String> {
        let mut out: Vec<String> = Vec::new();
        for e in &model.elements {
            out.extend(relation_findings(model, e).into_iter().map(|f| f.message));
        }
        out.extend(
            relation_whole_findings(model)
                .into_iter()
                .map(|f| f.message),
        );
        out
    }

    #[test]
    fn the_fixture_corpus_is_relation_clean() {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let messages = relation_messages(&model);
        assert!(messages.is_empty(), "corpus relation findings: {messages:#?}");
    }

    #[test]
    fn a_kind_is_declared_and_resolves() {
        let model = model_of(vec![read_model(
            "position",
            json!({
                "apparatus": { "type": "string", "format": "uuid",
                    "x-esdm-relation": { "to": "apparatus", "cardinality": "one" } }
            }),
        )]);
        let messages = relation_messages(&model);
        assert!(
            messages
                .iter()
                .any(|m| m.contains("without a resolvable to and kind")),
            "{messages:?}"
        );
    }

    #[test]
    fn shape_and_subkeys_follow_the_kind() {
        let model = model_of(vec![
            read_model(
                "apparatus",
                json!({
                    "id": { "type": "string", "format": "uuid" },
                    "positions": { "type": "string", "format": "uuid",
                        "x-esdm-relation": { "to": "position", "kind": "has_many", "inverse": "apparatus", "column": "x_id" } }
                }),
            ),
            read_model(
                "position",
                json!({
                    "apparatus": { "type": "string", "format": "uuid",
                        "x-esdm-relation": { "to": "apparatus", "kind": "belongs_to", "inverse": "positions" } }
                }),
            ),
        ]);
        let messages = relation_messages(&model);
        assert!(
            messages.iter().any(|m| m.contains("array of uuids by definition")),
            "{messages:?}"
        );
        assert!(
            messages.iter().any(|m| m.contains("column on \"positions\" is only for belongs_to")),
            "{messages:?}"
        );
    }

    #[test]
    fn both_sides_must_describe_the_same_edge() {
        let model = model_of(vec![
            read_model(
                "apparatus",
                json!({
                    "positions": { "type": "array",
                        "items": { "type": "string", "format": "uuid" },
                        "x-esdm-relation": { "to": "position", "kind": "has_many", "inverse": "mounted_on" } }
                }),
            ),
            read_model(
                "position",
                json!({
                    "apparatus": { "type": "string", "format": "uuid",
                        "x-esdm-relation": { "to": "apparatus", "kind": "belongs_to" } }
                }),
            ),
        ]);
        let messages = relation_messages(&model);
        assert!(
            messages
                .iter()
                .any(|m| m.contains("binds the far side \"mounted_on\" on position, which does not declare it")),
            "{messages:?}"
        );
    }

    #[test]
    fn a_unidirectional_claim_contradicts_a_returning_collection() {
        // position's belongs_to names no inverse, yet apparatus declares a
        // has_many binding it — the two statements must agree, and the
        // parent-side check reports the contradiction
        let model = model_of(vec![
            read_model(
                "apparatus",
                json!({
                    "positions": { "type": "array",
                        "items": { "type": "string", "format": "uuid" },
                        "x-esdm-relation": { "to": "position", "kind": "has_many", "inverse": "apparatus" } }
                }),
            ),
            read_model(
                "position",
                json!({
                    "apparatus": { "type": "string", "format": "uuid",
                        "x-esdm-relation": { "to": "apparatus", "kind": "belongs_to" } }
                }),
            ),
        ]);
        let messages = relation_messages(&model);
        assert!(
            messages
                .iter()
                .any(|m| m.contains("must name this property back with inverse: positions")),
            "{messages:?}"
        );
    }

    #[test]
    fn a_has_one_needs_the_childs_unique_edge() {
        let model = model_of(vec![
            read_model(
                "apparatus",
                json!({
                    "certification": { "type": "string", "format": "uuid",
                        "x-esdm-relation": { "to": "certificate", "kind": "has_one", "inverse": "apparatus" } }
                }),
            ),
            read_model(
                "certificate",
                json!({
                    "apparatus": { "type": "string", "format": "uuid",
                        "x-esdm-relation": { "to": "apparatus", "kind": "belongs_to", "inverse": "certification" } },
                    "renewed_from": { "type": "string", "format": "uuid",
                        "x-esdm-relation": { "to": "apparatus", "kind": "belongs_to" } }
                }),
            ),
        ]);
        let messages = relation_messages(&model);
        assert!(
            messages
                .iter()
                .any(|m| m.contains("has_one \"certification\" requires exactly one belongs_to to apparatus on certificate, but there are 2")),
            "{messages:?}"
        );
    }

    #[test]
    fn an_id_suffixed_data_field_that_matches_nothing_is_reported() {
        let mut command = element(
            "command",
            "catalog-position",
            json!({
                "data": {
                    "type": "object",
                    "properties": {
                        "title": { "type": "string" },
                        "apparatus_id": { "type": "string", "format": "uuid" },
                        "ghost_id": { "type": "string", "format": "uuid" }
                    },
                    "required": ["title"]
                },
                "publishes": []
            }),
        );
        command.address = "esdm:command=catalog-position".to_string();
        command.scope = vec![
            ("domain".to_string(), "sport".to_string()),
            ("boundedContext".to_string(), "sport".to_string()),
            ("aggregate".to_string(), "position".to_string()),
        ];
        let model = model_of(vec![
            read_model(
                "position",
                json!({
                    "title": { "type": "string" },
                    "apparatus": { "type": "string", "format": "uuid",
                        "x-esdm-relation": { "to": "apparatus", "kind": "belongs_to" } }
                }),
            ),
            read_model("apparatus", json!({ "title": { "type": "string" } })),
            command,
        ]);
        let messages = relation_messages(&model);
        assert!(
            messages.iter().any(|m| {
                m.contains("data field \"ghost_id\"") && m.contains("matches no relation")
            }),
            "{messages:?}"
        );
        assert!(
            !messages.iter().any(|m| m.contains("apparatus_id")),
            "the correlated field writes the edge and stays silent: {messages:?}"
        );
    }

    #[test]
    fn a_parent_set_never_writes_a_modeled_link() {
        let mut command = element(
            "command",
            "tag-movement",
            json!({
                "data": {
                    "type": "object",
                    "properties": {
                        "tag_ids": { "type": "array", "items": { "type": "string", "format": "uuid" } }
                    },
                    "required": ["tag_ids"]
                }
            }),
        );
        command.kind = ElementKind::Command;
        command.scope = vec![
            ("domain".to_string(), "sport".to_string()),
            ("boundedContext".to_string(), "sport".to_string()),
            ("aggregate".to_string(), "movement".to_string()),
        ];
        let movement = read_model(
            "movement",
            serde_json::json!({
                "tags": { "type": "array", "items": { "type": "string", "format": "uuid" },
                    "x-esdm-relation": { "to": "tag", "kind": "many_to_many", "join_model": "movement-tag", "inverse": "movements" } }
            }),
        );
        let tag = read_model(
            "tag",
            serde_json::json!({
                "movements": { "type": "array", "items": { "type": "string", "format": "uuid" },
                    "x-esdm-relation": { "to": "movement", "kind": "many_to_many", "join_model": "movement-tag", "inverse": "tags" } }
            }),
        );
        let link = read_model(
            "movement-tag",
            serde_json::json!({
                "movement": { "type": "string", "format": "uuid",
                    "x-esdm-relation": { "to": "movement", "kind": "belongs_to" } },
                "tag": { "type": "string", "format": "uuid",
                    "x-esdm-relation": { "to": "tag", "kind": "belongs_to" } }
            }),
        );
        let messages = relation_messages(&model_of(vec![movement, tag, link, command]));
        assert!(
            messages.iter().any(|m| {
                m.contains("data field \"tag_ids\" sets the modeled link") && m.contains("join_model owns its rows")
            }),
            "{messages:?}"
        );
    }

    #[test]
    fn two_pairs_never_share_one_join_storage() {
        let model = model_of(vec![
            read_model(
                "movement",
                json!({
                    "tags": { "type": "array", "items": { "type": "string", "format": "uuid" },
                        "x-esdm-relation": { "to": "tag", "kind": "many_to_many", "join_table": "shared_links", "inverse": "movements" } }
                }),
            ),
            read_model(
                "tag",
                json!({
                    "movements": { "type": "array", "items": { "type": "string", "format": "uuid" },
                        "x-esdm-relation": { "to": "movement", "kind": "many_to_many", "join_table": "shared_links", "inverse": "tags" } },
                    "sports": { "type": "array", "items": { "type": "string", "format": "uuid" },
                        "x-esdm-relation": { "to": "sport", "kind": "many_to_many", "join_table": "shared_links", "inverse": "tags" } }
                }),
            ),
            read_model(
                "sport",
                json!({
                    "tags": { "type": "array", "items": { "type": "string", "format": "uuid" },
                        "x-esdm-relation": { "to": "tag", "kind": "many_to_many", "join_table": "shared_links", "inverse": "sports" } }
                }),
            ),
        ]);
        let messages = relation_messages(&model);
        let shared: Vec<&String> = messages
            .iter()
            .filter(|m| m.contains("shares join storage table:shared_links"))
            .collect();
        assert!(!shared.is_empty(), "{messages:?}");
    }

    #[test]
    fn a_join_model_is_two_edges_and_nothing_more() {
        let model = model_of(vec![
            read_model(
                "movement",
                json!({
                    "tags": { "type": "array", "items": { "type": "string", "format": "uuid" },
                        "x-esdm-relation": { "to": "tag", "kind": "many_to_many", "join_model": "bad-link", "inverse": "movements" } }
                }),
            ),
            read_model(
                "tag",
                json!({
                    "movements": { "type": "array", "items": { "type": "string", "format": "uuid" },
                        "x-esdm-relation": { "to": "movement", "kind": "many_to_many", "join_model": "bad-link", "inverse": "tags" } }
                }),
            ),
            read_model(
                "bad-link",
                json!({
                    "movement": { "type": "string", "format": "uuid",
                        "x-esdm-relation": { "to": "movement", "kind": "belongs_to" } }
                }),
            ),
        ]);
        let messages = relation_messages(&model);
        assert!(
            messages.iter().any(|m| {
                m.contains("join_model \"bad-link\" must carry exactly two belongs_to properties, one to movement and one to tag")
            }),
            "{messages:?}"
        );
    }

    #[test]
    fn a_join_table_never_names_a_read_model_table() {
        let model = model_of(vec![
            read_model(
                "position",
                json!({
                    "apparatus_id": { "type": "string" }
                }),
            ),
        ]);
        let messages = relation_messages(&model);
        // plain data with an _id tail that matches a plain property is fine
        assert!(messages.is_empty(), "{messages:?}");

        let model = model_of(vec![
            read_model(
                "movement",
                json!({
                    "tags": { "type": "array", "items": { "type": "string", "format": "uuid" },
                        "x-esdm-relation": { "to": "tag", "kind": "many_to_many", "join_table": "position", "inverse": "movements" } }
                }),
            ),
            read_model(
                "tag",
                json!({
                    "movements": { "type": "array", "items": { "type": "string", "format": "uuid" },
                        "x-esdm-relation": { "to": "movement", "kind": "many_to_many", "join_table": "position", "inverse": "tags" } }
                }),
            ),
            position(),
        ]);
        let messages = relation_messages(&model);
        assert!(
            messages
                .iter()
                .any(|m| m.contains("join table \"position\" of \"tags\" names the table of a read model")),
            "{messages:?}"
        );
    }

    fn position() -> Element {
        read_model("position", json!({ "title": { "type": "string" } }))
    }
}
