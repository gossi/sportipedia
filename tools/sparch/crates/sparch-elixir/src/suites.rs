//! Slices — the tier above generators: one scope, the generators it needs,
//! in the known-good build order (README decision 11).
//!
//! A suite is orchestration, never a fourth engine: it resolves the input
//! element's neighborhood, refuses until every member generator is ported
//! (a half-suite silently under-generating is worse than an error), then
//! runs each generator exactly as its own command would and prints one
//! merged report. Deferral, gates, exit codes and `--dry-run` semantics all
//! pass through untouched.
//!
//! The scopes mirror the recipes in `.opencode/recipes/`:
//! `operation` (domain actor of one command or query), `endpoint` (web
//! actor of one operation), `feature` (the whole constituent — every
//! operation, both actors, test support included).

use std::path::Path;

use sparch_model::{Element, ElementKind, Model, ResolveError};

use crate::blueprints;
use crate::engine::{self, Row};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Suite {
    Operation,
    Endpoint,
    Feature,
}

impl Suite {
    pub fn parse(name: &str) -> Option<Suite> {
        match name {
            "operation" => Some(Suite::Operation),
            "endpoint" => Some(Suite::Endpoint),
            "feature" => Some(Suite::Feature),
            _ => None,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Suite::Operation => "operation",
            Suite::Endpoint => "endpoint",
            Suite::Feature => "feature",
        }
    }

    /// Every member generator the scope runs, in build order — the
    /// capability tree and the listing state pending membership from it.
    /// The sequence mirrors `plan`; an actual run resolves elements per
    /// input, this is the static truth of what the scope covers.
    pub fn members(&self) -> &'static [&'static str] {
        match self {
            Suite::Operation => &[
                "read_model",
                "event",
                "aggregate",
                "query",
                "command",
                "command_handler",
                "projector",
                "policy",
                "public_api",
            ],
            Suite::Endpoint => &["view", "schema", "controller", "bruno"],
            Suite::Feature => &[
                "read_model",
                "test_support",
                "event",
                "aggregate",
                "query",
                "command",
                "command_handler",
                "projector",
                "policy",
                "public_api",
                "view",
                "schema",
                "controller",
                "bruno",
            ],
        }
    }

    /// The element kinds a suite is driven from.
    fn input_kinds(&self) -> Vec<ElementKind> {
        match self {
            Suite::Operation | Suite::Endpoint => {
                vec![ElementKind::Command, ElementKind::Query]
            }
            Suite::Feature => vec![ElementKind::Aggregate, ElementKind::ReadModel],
        }
    }
}

/// One suite step: the generator to run and the element it is driven from.
#[derive(Debug)]
pub struct Member {
    pub generator: &'static str,
    pub element: Element,
}

/// The member sequence of a suite, in build order.
pub fn plan(model: &Model, suite: Suite, input: &Element) -> Result<Vec<Member>, String> {
    match suite {
        Suite::Operation => operation_suite(model, input),
        Suite::Endpoint => endpoint_suite(model, input),
        Suite::Feature => feature_suite(model, input),
    }
}

fn constituent_of(_model: &Model, input: &Element) -> Option<String> {
    match input.kind {
        ElementKind::Command | ElementKind::Event | ElementKind::Aggregate => {
            Some(input.aggregate_name().unwrap_or(&input.name).to_string())
        }
        ElementKind::Query => input.read_model_name().map(str::to_string),
        ElementKind::ReadModel => Some(input.name.clone()),
        _ => None,
    }
}

fn need(
    model: &Model,
    kind: ElementKind,
    name: Option<&str>,
    suite: Suite,
    what: &str,
) -> Result<Option<Element>, String> {
    let Some(name) = name else {
        return Ok(None);
    };
    match model.find(kind, name) {
        Some(e) => Ok(Some(e)),
        None => Err(format!(
            "suite {} cannot run — the model holds no {what} named `{name}` (fix the model or run sparch validate)",
            suite.as_str()
        )),
    }
}

fn push(members: &mut Vec<Member>, generator: &'static str, element: &Element) {
    members.push(Member {
        generator,
        element: element.clone(),
    });
}

fn operation_suite(model: &Model, input: &Element) -> Result<Vec<Member>, String> {
    let constituent = constituent_of(model, input).ok_or_else(|| {
        format!(
            "suite operation is driven from a command or a query, got {} ({})",
            ElementKind::as_str(&input.kind),
            input.address
        )
    })?;
    let rm = need(
        model,
        ElementKind::ReadModel,
        Some(&constituent),
        Suite::Operation,
        "read model",
    )?;
    let agg = need(
        model,
        ElementKind::Aggregate,
        Some(&constituent),
        Suite::Operation,
        "aggregate",
    )?;

    let events: Vec<Element> = match input.kind {
        ElementKind::Command => input
            .publishes()
            .iter()
            .filter_map(|name| model.find(ElementKind::Event, name))
            .collect(),
        _ => Vec::new(),
    };

    let mut members = Vec::new();
    if let Some(rm) = &rm {
        push(&mut members, "read_model", rm);
    }
    // The internal API is NOT a suite member:
    // the command's blueprint dependencies already generate it, with the
    // validators and lookup queries behind it. A suite lists commands, not
    // their internals.
    if input.kind == ElementKind::Command {
        for e in &events {
            push(&mut members, "event", e);
        }
        if let Some(agg) = &agg {
            push(&mut members, "aggregate", agg);
        }
    } else {
        push(&mut members, "query", input);
    }
    if input.kind == ElementKind::Command {
        push(&mut members, "command", input);
        push(&mut members, "command_handler", input);
        for e in &events {
            push(&mut members, "projector", e);
        }
    }
    push(&mut members, "policy", input);
    push(&mut members, "public_api", input);
    Ok(members)
}

fn endpoint_suite(model: &Model, input: &Element) -> Result<Vec<Member>, String> {
    let constituent = constituent_of(model, input).ok_or_else(|| {
        format!(
            "suite endpoint is driven from a command or a query, got {} ({})",
            ElementKind::as_str(&input.kind),
            input.address
        )
    })?;
    let rm = need(
        model,
        ElementKind::ReadModel,
        Some(&constituent),
        Suite::Endpoint,
        "read model",
    )?;

    let mut members = Vec::new();
    if let Some(rm) = &rm {
        push(&mut members, "view", rm);
    }
    push(&mut members, "schema", input);
    push(&mut members, "controller", input);
    push(&mut members, "bruno", input);
    Ok(members)
}

fn feature_suite(model: &Model, input: &Element) -> Result<Vec<Member>, String> {
    let constituent = constituent_of(model, input).ok_or_else(|| {
        format!(
            "suite feature is driven from the constituent (aggregate or read model), got {} ({})",
            ElementKind::as_str(&input.kind),
            input.address
        )
    })?;
    let agg = need(
        model,
        ElementKind::Aggregate,
        Some(&constituent),
        Suite::Feature,
        "aggregate",
    )?;
    let rm = need(
        model,
        ElementKind::ReadModel,
        Some(&constituent),
        Suite::Feature,
        "read model",
    )?;

    let events = model.events_of(&constituent);
    let commands = model.commands_of(&constituent);
    let queries = model.queries_of(&constituent);
    let mut operations: Vec<Element> = Vec::new();
    operations.extend(commands.iter().cloned());
    operations.extend(queries.iter().cloned());

    let mut members = Vec::new();
    if let Some(rm) = &rm {
        push(&mut members, "read_model", rm);
        push(&mut members, "test_support", rm);
    }
    for e in &events {
        push(&mut members, "event", e);
    }
    if let Some(agg) = &agg {
        push(&mut members, "aggregate", agg);
    }
    for q in &queries {
        push(&mut members, "query", q);
    }
    // internal_api arrives through the command blueprints' dependency
    // expansion, as in the documented per-operation sequence
    for c in &commands {
        push(&mut members, "command", c);
    }
    for c in &commands {
        push(&mut members, "command_handler", c);
    }
    for e in &events {
        push(&mut members, "projector", e);
    }
    for op in &operations {
        push(&mut members, "policy", op);
    }
    for op in &operations {
        push(&mut members, "public_api", op);
    }
    // the web actor follows the known-good order: view → schema → controller → bruno
    if let Some(rm) = &rm {
        push(&mut members, "view", rm);
    }
    for op in &operations {
        push(&mut members, "schema", op);
    }
    for op in &operations {
        push(&mut members, "controller", op);
    }
    for op in &operations {
        push(&mut members, "bruno", op);
    }
    Ok(members)
}

/// Generators the suite needs that are not ported yet, in build order,
/// deduped. Non-empty means the suite refuses.
pub fn missing_members(members: &[Member]) -> Vec<&'static str> {
    let mut missing: Vec<&'static str> = Vec::new();
    for m in members {
        if blueprints::blueprint_for(m.generator).is_none() && !missing.contains(&m.generator) {
            missing.push(m.generator);
        }
    }
    missing
}

/// Resolve the input element of a suite. A constituent name naming both
/// an aggregate and a read model is one citizen, not an ambiguity — the
/// aggregate is the canonical driver.
pub fn resolve_input(model: &Model, suite: Suite, address: &str) -> Result<Element, String> {
    if suite == Suite::Feature {
        match model.resolve(address, &[ElementKind::Aggregate]) {
            Ok(e) => return Ok(e),
            Err(ResolveError::Unknown(_)) | Err(ResolveError::KindMismatch { .. }) => {}
            Err(other) => return Err(format!("cannot resolve element: {other}")),
        }
    }
    model
        .resolve(address, &suite.input_kinds())
        .map_err(|e| format!("cannot resolve element: {e}"))
}

/// Run the suite: gate on membership, then run each generator over its
/// element with the operator's options passed through. Rows of all members
/// merge into one report; a member hard-failing stops the sequence and is
/// reported under Failed with the rest of the run's rows still shown.
pub fn run(
    suite: Suite,
    opts: &crate::engine::RunOptions,
    address: &str,
    cwd: &Path,
) -> Result<Vec<Row>, String> {
    if opts.given_template.is_some() {
        return Err(format!(
            "suite {} takes no --template — every member generator reads the operation from the model",
            suite.as_str()
        ));
    }

    let repo_root = match &opts.root {
        Some(root) => std::path::PathBuf::from(root),
        None => engine::find_root(cwd),
    };
    let model_root = match &opts.model {
        Some(model) => repo_root.join(model),
        None => repo_root.join("docs/domain-model"),
    };
    let model = Model::load(&model_root);
    let input = resolve_input(&model, suite, address)?;
    let members = plan(&model, suite, &input)?;

    let missing = missing_members(&members);
    if !missing.is_empty() {
        return Err(format!(
            "suite {} needs generators not ported to sparch-elixir yet: {} — until every member is green, run `mix sp.gen.<name> <element>` in the order the suite defines (the Elixir tool)",
            suite.as_str(),
            missing.join(", ")
        ));
    }

    let mut rows = Vec::new();
    for member in members {
        // the membership gate proved the head is ported; run the whole
        // registry entry like the member's own command would
        let modules = blueprints::generator_modules(member.generator);
        assert!(
            !modules.is_empty(),
            "membership gate passed but {} lost its primary",
            member.generator
        );
        let member_opts = crate::engine::RunOptions {
            template: None,
            given_template: None,
            subdomain: opts.subdomain.clone(),
            composite: opts.composite.clone(),
            constituent: opts.constituent.clone(),
            model: opts.model.clone(),
            root: opts.root.clone(),
            dry_run: opts.dry_run,
            verbose: opts.verbose,
        };
        match engine::run(&modules, &member_opts, &member.element.address, cwd) {
            Ok(member_rows) => rows.extend(member_rows),
            Err(message) => {
                rows.push(Row::Error(format!("suite {}", member.generator), message));
                break;
            }
        }
    }
    Ok(rows)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn corpus() -> Model {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        Model::load(&root.canonicalize().expect("shared fixture corpus"))
    }

    fn generators(members: &[Member]) -> Vec<&'static str> {
        members.iter().map(|m| m.generator).collect()
    }

    #[test]
    fn command_operation_suite_reads_in_build_order() {
        let model = corpus();
        let input = resolve_input(&model, Suite::Operation, "create-widget").unwrap();
        let members = plan(&model, Suite::Operation, &input).unwrap();
        assert_eq!(
            generators(&members),
            vec![
                "read_model",
                "event",
                "aggregate",
                "command",
                "command_handler",
                "projector",
                "policy",
                "public_api",
            ]
        );
        // every member element is the operation's own neighborhood
        for m in &members {
            assert!(
                m.element.name.contains("widget") || m.element.name.starts_with("widget-"),
                "stray element {} in the widget suite",
                m.element.address
            );
        }
        assert_eq!(members[0].element.kind, ElementKind::ReadModel);
        assert_eq!(members[2].element.kind, ElementKind::Aggregate);
    }

    #[test]
    fn query_operation_suite_has_no_command_members() {
        let model = corpus();
        let input = resolve_input(&model, Suite::Operation, "read-widget").unwrap();
        let members = plan(&model, Suite::Operation, &input).unwrap();
        assert_eq!(
            generators(&members),
            vec!["read_model", "query", "policy", "public_api"]
        );
    }

    #[test]
    fn endpoint_suite_is_the_web_actor_only() {
        let model = corpus();
        let input = resolve_input(&model, Suite::Endpoint, "create-widget").unwrap();
        let members = plan(&model, Suite::Endpoint, &input).unwrap();
        assert_eq!(
            generators(&members),
            vec!["view", "schema", "controller", "bruno"]
        );
        assert_eq!(members[0].element.kind, ElementKind::ReadModel);
        assert_eq!(members[1].element.kind, ElementKind::Command);
    }

    #[test]
    fn feature_suite_covers_every_operation_both_actors() {
        let model = corpus();
        let input = resolve_input(&model, Suite::Feature, "widget").unwrap();
        assert_eq!(input.kind, ElementKind::Aggregate);
        let members = plan(&model, Suite::Feature, &input).unwrap();
        let gens = generators(&members);
        // widget: 5 commands, 2 queries, 6 events (sorted by name)
        assert_eq!(gens.iter().filter(|g| **g == "command").count(), 5);
        assert_eq!(gens.iter().filter(|g| **g == "command_handler").count(), 5);
        assert_eq!(gens.iter().filter(|g| **g == "event").count(), 6);
        assert_eq!(gens.iter().filter(|g| **g == "projector").count(), 6);
        assert_eq!(gens.iter().filter(|g| **g == "query").count(), 2);
        assert_eq!(gens.iter().filter(|g| **g == "policy").count(), 7);
        assert_eq!(gens.iter().filter(|g| **g == "public_api").count(), 7);
        assert_eq!(gens.iter().filter(|g| **g == "bruno").count(), 7);
        // internal API is never a member — the command blueprints pull it
        assert!(!gens.contains(&"internal_api"));
        // domain actor before web actor, build order preserved at the head
        assert_eq!(
            &gens[..4],
            &["read_model", "test_support", "event", "event"]
        );
        assert_eq!(*gens.last().unwrap(), "bruno");
    }

    #[test]
    fn missing_membership_lists_in_suite_order() {
        let model = corpus();
        let input = resolve_input(&model, Suite::Endpoint, "create-widget").unwrap();
        let members = plan(&model, Suite::Endpoint, &input).unwrap();
        assert_eq!(missing_members(&members), Vec::<&str>::new());
        let input = resolve_input(&model, Suite::Feature, "widget").unwrap();
        let members = plan(&model, Suite::Feature, &input).unwrap();
        assert_eq!(missing_members(&members), Vec::<&str>::new());
    }

    #[test]
    fn suiterefuses_template() {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/repo");
        let opts = crate::engine::RunOptions {
            template: Some("create".into()),
            given_template: Some("create".into()),
            root: Some(root.canonicalize().unwrap().to_string_lossy().to_string()),
            ..Default::default()
        };
        let err = run(Suite::Operation, &opts, "create-widget", Path::new("/")).unwrap_err();
        assert!(err.contains("takes no --template"), "{err}");
    }
}
