//! The run engine: options, resolution,
//! planning (with dependency expansion), append-only application, the
//! neighborhood closure with deferral back-fill, and the row contract the
//! report renders.

use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::rc::Rc;

use sparch_model::{Element, ElementKind, Model};

use crate::blueprints;
use crate::context::{Context, ContextError, ContextOptions, Operation, derive_operation};
use crate::elixir::ElixirFile;
use crate::plan::{Blueprint, ClosureScope, FilePlan, UnitId};
use crate::report::{self, CheckId};

/// The per-file result rows of a run.
#[derive(Debug)]
pub enum Row {
    Created(String),
    Merged(String, Vec<String>),
    Backfill(String, Vec<String>),
    Unchanged(String),
    Rewritten(String),
    Deferred(String, Vec<String>),
    Stale(String, Vec<String>),
    Unresolved(String, Vec<String>),
    Checked(String, Vec<CheckId>),
    Blocked(String, Vec<String>),
    /// One file's `--diff` findings, as pre-formatted detail lines. A
    /// `Drift` row exists only when the file drifts; the CLI exits 3 on it.
    Drift(String, Vec<String>),
    Error(String, String),
}

#[derive(Default, Clone)]
pub struct RunOptions {
    pub template: Option<String>,
    pub given_template: Option<String>,
    pub subdomain: Option<String>,
    pub composite: Option<String>,
    pub constituent: Option<String>,
    pub model: Option<String>,
    pub root: Option<String>,
    pub dry_run: bool,
    pub verbose: bool,
    /// report model-vs-code drift per unit, write nothing (implies
    /// `dry_run`)
    pub diff: bool,
}

/// The run state threaded through plan application.
struct Applied {
    repo_root: PathBuf,
    dry_run: bool,
    merge_only: bool,
    creating: bool,
    planned: HashSet<String>,
    /// Content-keyed parse cache: closure rounds re-merge the same text
    /// through several plan groups; parsing is the dominant cost.
    parses: HashMap<String, ElixirFile>,
}

impl Applied {
    fn parsed(&mut self, text: &str) -> &ElixirFile {
        if !self.parses.contains_key(text) {
            self.parses
                .insert(text.to_string(), ElixirFile::parse(text));
        }
        self.parses.get(text).unwrap()
    }

    fn existing(&self, path: &str) -> bool {
        self.planned.contains(path) || self.repo_root.join(path).exists()
    }
}

/// Everything a run resolves and plans before it touches a file: the
/// plans, the model, the context, and the context options the closure
/// rounds need. `run` consumes it; the suite's `--diff` path collects
/// member plans across generators and diffs the union once.
pub struct Build {
    pub repo_root: PathBuf,
    pub plans: Vec<(FilePlan, Context)>,
    pub model: Model,
    pub ctx: Context,
    pub ctx_opts: ContextOptions,
}

/// Resolve, validate, and plan one generator against one element address.
/// Reads the model and nothing else; writes nothing.
pub fn build(
    modules: &[&dyn Blueprint],
    opts: &RunOptions,
    address: &str,
    cwd: &Path,
) -> Result<Build, String> {
    let blueprint = modules
        .first()
        .copied()
        .ok_or_else(|| "generator has no ported blueprint".to_string())?;
    let repo_root = match &opts.root {
        Some(root) => PathBuf::from(root),
        None => find_root(cwd),
    };
    let model_root = match &opts.model {
        Some(model) => repo_root.join(model),
        None => repo_root.join("docs/domain-model"),
    };

    let model = Model::load(&model_root);
    let element = model
        .resolve(address, &blueprint.source_kinds())
        .map_err(|e| format!("cannot resolve element: {e}"))?;

    if !element_accepted(blueprint, &element) {
        return Err(format!(
            "{} generates from {:?} elements, got {} ({})",
            blueprint.name(),
            blueprint
                .source_kinds()
                .iter()
                .map(|k| ElementKind::as_str(k))
                .collect::<Vec<_>>(),
            ElementKind::as_str(&element.kind),
            element.address
        ));
    }

    let operation = validate_operation(blueprint, opts, &element.kind)?;

    let ctx_opts = ContextOptions {
        operation,
        subdomain: opts.subdomain.clone(),
        composite: opts.composite.clone(),
        constituent: opts.constituent.clone(),
        repo_root: repo_root.clone(),
    };
    let ctx = Context::build(&model, &element, &ctx_opts).map_err(|e| {
        let ContextError::UnknownLocation(var) = e;
        format!(
            "cannot infer {var} for {} — pass --{var} <name> (subdomain/composite come from the model layout, constituent from the element scope)",
            element.address
        )
    })?;

    // The model-content gate of the primary blueprint runs after
    // the context resolves and before anything is planned or written.
    // The error message names the blueprint and element, with the kind
    // inspected (`:command`).
    if let Err(messages) = blueprint.validate(&ctx) {
        return Err(format!(
            "{} :{}.{} cannot generate — the model needs fixing:\n{}",
            blueprint.name(),
            ElementKind::as_str(&element.kind),
            element.name,
            messages.join("\n")
        ));
    }

    require_operation(&element, &ctx)?;

    let plans = plans_for(&model, modules, &ctx);

    Ok(Build {
        repo_root,
        plans,
        model,
        ctx,
        ctx_opts,
    })
}

/// Runs one generator against one resolved element address. `modules` is
/// the generator's registry entry — every *ported* blueprint module, head
/// first. The run takes the whole module list while the head owns the
/// element kinds and `--template` semantics. Argument syntax is the CLI's
/// (clap's) business; this returns rows or a hard error message.
/// With `--diff` it answers the structural diff of the plans against the
/// tree instead of applying them, and still states model-completeness
/// guidance.
pub fn run(
    modules: &[&dyn Blueprint],
    opts: &RunOptions,
    address: &str,
    cwd: &Path,
) -> Result<Vec<Row>, String> {
    let blueprint = modules
        .first()
        .copied()
        .ok_or_else(|| "generator has no ported blueprint".to_string())?;
    let Build {
        repo_root,
        plans,
        model,
        ctx,
        ctx_opts,
    } = build(modules, opts, address, cwd)?;

    if opts.diff {
        let mut rows = crate::diff::run(&plans, &repo_root, opts.verbose);
        rows.extend(unresolved_rows(&ctx));
        rows.extend(effect_gap_rows(&model, &ctx));
        return Ok(rows);
    }

    let mut applied = Applied {
        repo_root: repo_root.clone(),
        dry_run: opts.dry_run,
        merge_only: false,
        creating: false,
        planned: HashSet::new(),
        parses: HashMap::new(),
    };

    let (mut rows, created) = apply_plans(&plans, &mut applied);
    let backfill = if created && blueprint.closure_scope() == ClosureScope::All && !opts.dry_run {
        closure_rounds(&model, &ctx, &ctx_opts, &mut applied)
    } else {
        Vec::new()
    };

    rows.extend(backfill);
    rows.extend(unresolved_rows(&ctx));
    rows.extend(effect_gap_rows(&model, &ctx));
    Ok(rows)
}

fn element_accepted(blueprint: &dyn Blueprint, element: &Element) -> bool {
    blueprint.source_kinds().contains(&element.kind)
}

// ----------------------------------------------------------------- options

/// The template vocabulary check for
/// every blueprint shape. The check inspects the requested atom, so the
/// error texts carry the leading colon (`template :read not supported…`),
/// and a given template must both be supported by the blueprint and fit
/// the element kind.
fn validate_operation(
    blueprint: &dyn Blueprint,
    opts: &RunOptions,
    kind: &ElementKind,
) -> Result<Option<Operation>, String> {
    if blueprint.is_fixed() {
        if opts.given_template.is_some() {
            return Err(format!(
                "{} is fixed — it takes no --template (remove it)",
                blueprint.name()
            ));
        }
        return Ok(None);
    }
    let given = match &opts.given_template {
        None => {
            return if blueprint.optional_template() {
                Ok(None)
            } else {
                Err(format!(
                    "{} needs --template, one of: {}",
                    blueprint.name(),
                    ops_text(&blueprint.operations())
                ))
            };
        }
        Some(word) => word,
    };
    let ops = blueprint.operations();
    let requested = Operation::parse(given);
    if !requested.is_some_and(|op| ops.contains(&op)) {
        return Err(format!(
            "template :{given} not supported by {} — one of: {}",
            blueprint.name(),
            ops_text(&ops)
        ));
    }
    // Commands and events perform
    // create | update | delete, queries read | collection.
    let kind_ops: Option<Vec<Operation>> = match kind {
        ElementKind::Command | ElementKind::Event => Some(vec![
            Operation::Create,
            Operation::Update,
            Operation::Delete,
            Operation::None,
        ]),
        ElementKind::Query => Some(vec![Operation::Read, Operation::Collection]),
        _ => None,
    };
    if let (Some(list), Some(op)) = (&kind_ops, requested)
        && !list.contains(&op)
    {
        return Err(format!(
            "template :{given} does not fit a {} element — one of: {}",
            ElementKind::as_str(kind),
            ops_text(list)
        ));
    }
    Ok(requested)
}

fn ops_text(ops: &[Operation]) -> String {
    ops.iter()
        .map(|o| o.as_str())
        .collect::<Vec<_>>()
        .join(", ")
}

/// A command with neither a model declaration nor `--template` is refused
/// where the message names both possible fixes.
fn require_operation(element: &Element, ctx: &Context) -> Result<(), String> {
    if element.kind == ElementKind::Command && ctx.operation.is_none() {
        return Err(format!(
            "no operation declared for command {} — add metadata.annotations.spgen.operation \
             (create|update|delete|none) to {}, or pass --template",
            element.name,
            element.source.display()
        ));
    }
    Ok(())
}

/// Repo root discovery: the nearest ancestor holding both `services/api`
/// and `docs/domain-model`.
pub fn find_root(cwd: &Path) -> PathBuf {
    let mut dir = cwd.to_path_buf();
    loop {
        if dir.join("services/api").is_dir() && dir.join("docs/domain-model").is_dir() {
            return dir;
        }
        if !dir.pop() {
            return cwd.to_path_buf();
        }
    }
}

/// CLI help text shared by all sp.gen tasks.
/// The element-address forms and option lore, shared by `--help`
/// (clap `after_help`) and the curated usage errors.
pub const HELP: &str = r#"<element> is one of:
  * an esdm: reference — esdm:domain=sport/bounded-context=sport/aggregate=apparatus/command=catalog-apparatus
  * a *.esdm.yaml model file — docs/domain-model/catalog/equipment/command.catalog-apparatus.esdm.yaml
  * kind.name — command.catalog-apparatus
  * a bare name — resolved among the kinds this generator produces
    (so `sp.gen.aggregate widget` finds the aggregate, not the
    same-named read model; `kind.name` or an esdm: reference always
    disambiguates)

Options:
  --template       what the operation does: create | update | delete | none | read | collection
                   (default: the operation DECLARED in the model —
                   metadata.annotations."spgen.operation" on commands,
                   "spgen.operation.<event>" on read models — or, for
                   queries, the shape of the result)
  --subdomain      override the inferred subdomain
  --composite      override the inferred composite
  --constituent    override the inferred constituent (domain object)
  --model          model root, default docs/domain-model (relative to --root)
  --root           repo root, default inferred from the current directory
  --dry-run        report the drift, write nothing
  --verbose        with --dry-run, list the units that would land, wait, or block
                   (with --diff, also list the units that were compared and found)
  --diff           compare model and code per unit — added, changed, removed,
                   deferred, blocked — and write nothing; exits 3 on drift

Slices (generators of one scope, in build order — refused until every
member generator is ported here):
  operation <command|query>  domain actor of one operation: read model, events,
                             aggregate, command, handler, projectors, policy,
                             public API (validators and internal API arrive as
                             the command's blueprint dependencies)
  endpoint  <command|query>  web actor of one operation: view, schema,
                             controller, bruno
  feature   <aggregate>      the whole constituent: test support, every
                             operation suite, every endpoint suite
"#;

/// CLI help text shared by all sp.gen tasks.
pub fn help() -> String {
    HELP.to_string()
}

// --------------------------------------------------------------- planning

/// The plans of a run: every blueprint module of the generator's registry
/// entry — head first, each from the same context — and, before each, the
/// plans of the blueprints its code calls. A module
/// plans exactly once across the whole list (the shared `seen` set), so a
/// dependency shared by several callers appears once, ahead of all of
/// them; the plan order keeps the citizen's own file ahead of its test
/// file on a fresh tree.
fn plans_for(model: &Model, modules: &[&dyn Blueprint], ctx: &Context) -> Vec<(FilePlan, Context)> {
    let mut seen: HashSet<String> = HashSet::new();
    let mut plans = Vec::new();
    for module in modules {
        plan_module(model, *module, ctx, &mut seen, &mut plans);
    }
    plans
}

fn plan_module(
    model: &Model,
    blueprint: &dyn Blueprint,
    ctx: &Context,
    seen: &mut HashSet<String>,
    plans: &mut Vec<(FilePlan, Context)>,
) {
    if seen.contains(blueprint.name()) {
        return;
    }
    seen.insert(blueprint.name().to_string());
    for dep in blueprint.dependencies(ctx) {
        // a dependency with no element to plan from is skipped: its caller's
        // reference gates defer as they always did
        let dep_ctx = Context::build(
            model,
            &dep.element,
            &ContextOptions {
                operation: derive_operation(model, &dep.element),
                subdomain: Some(ctx.subdomain.clone()),
                composite: Some(ctx.composite.clone()),
                constituent: Some(ctx.constituent.clone()),
                repo_root: ctx.repo_root.clone(),
            },
        );
        if let Ok(dep_ctx) = dep_ctx
            && let Some(dep_bp) = blueprints::by_name(dep.blueprint_name)
        {
            plan_module(model, dep_bp, &dep_ctx, seen, plans);
        }
    }
    for plan in blueprint.plans(ctx) {
        plans.push((plan, ctx.clone()));
    }
}

// -------------------------------------------------------------- applying

/// Apply the plans, threading the run state; returns rows and whether any
/// file was created.
fn apply_plans(plans: &[(FilePlan, Context)], applied: &mut Applied) -> (Vec<Row>, bool) {
    let mut rows = Vec::new();
    let mut created = false;
    for (plan, ctx) in plans {
        let plan_rows = apply_plan(plan, ctx, applied);
        created |= plan_rows.iter().any(|r| matches!(r, Row::Created(_)));
        rows.extend(plan_rows);
    }
    (rows, created)
}

fn apply_plan(plan: &FilePlan, ctx: &Context, applied: &mut Applied) -> Vec<Row> {
    if plan.projection {
        return apply_projection(plan, applied);
    }
    let abs = ctx.repo_root.join(&plan.path);
    match std::fs::read_to_string(&abs) {
        Ok(text) => merge(plan, ctx, &text, applied),
        Err(_) => create(plan, ctx, &abs, applied),
    }
}

/// A projection is gated, not merge-restricted: its content depends on
/// nothing but the model, so a re-render of equal content is `Unchanged`,
/// never a rewrite, and a differing one rewrites the file wholesale.
fn apply_projection(plan: &FilePlan, applied: &mut Applied) -> Vec<Row> {
    let unmet: Vec<String> = plan
        .gate
        .iter()
        .filter(|(path, _)| !applied.existing(path))
        .map(|(_, reason)| reason.clone())
        .collect();
    if !unmet.is_empty() {
        return vec![Row::Deferred(plan.path.clone(), unmet)];
    }
    let Some(content) = &plan.scaffold else {
        return vec![Row::Error(
            plan.path.clone(),
            "projection without a render".to_string(),
        )];
    };
    let abs = applied.repo_root.join(&plan.path);
    match std::fs::read_to_string(&abs) {
        Ok(text) if text == *content => vec![Row::Unchanged(plan.path.clone())],
        Ok(_) => {
            if applied.dry_run {
                return vec![Row::Checked(plan.path.clone(), vec![CheckId::Rewrite])];
            }
            write_file(&abs, content);
            applied.planned.insert(plan.path.clone());
            vec![Row::Rewritten(plan.path.clone())]
        }
        Err(_) => {
            if applied.dry_run {
                return vec![Row::Checked(plan.path.clone(), vec![CheckId::WholeFile])];
            }
            write_file(&abs, content);
            applied.planned.insert(plan.path.clone());
            vec![Row::Created(plan.path.clone())]
        }
    }
}

fn create(plan: &FilePlan, _ctx: &Context, abs: &Path, applied: &mut Applied) -> Vec<Row> {
    if applied.merge_only {
        // the closure pass never creates — a citizen materializes via its own run
        return Vec::new();
    }

    if plan.unit_created {
        // units apply to the in-memory shell; the file appears only once it
        // has content, so a shell alone is never written
        applied.creating = true;
        let shell = format!(
            "defmodule {} do\nend\n",
            plan.module.clone().unwrap_or_default()
        );
        let rows = place_units(plan, &shell, abs, applied);
        applied.creating = false;
        return rows;
    }

    match &plan.scaffold {
        None => vec![Row::Error(
            plan.path.clone(),
            "registration_file_missing".to_string(),
        )],
        Some(scaffold) => {
            // the trailing newline is the tool's contract; project
            // formatting is applied by the mix binding after the run
            let content = format!("{}\n", scaffold.trim_end_matches('\n'));
            if applied.dry_run {
                vec![Row::Checked(plan.path.clone(), vec![CheckId::WholeFile])]
            } else {
                write_file(abs, &content);
                applied.planned.insert(plan.path.clone());
                vec![Row::Created(plan.path.clone())]
            }
        }
    }
}

fn merge(plan: &FilePlan, ctx: &Context, text: &str, applied: &mut Applied) -> Vec<Row> {
    if !plan.format {
        // text artifacts are create-only: existing docs are never rewritten
        return vec![Row::Unchanged(plan.path.clone())];
    }
    let file = applied.parsed(text);
    if !file.parsed() {
        return vec![Row::Error(plan.path.clone(), "unparsable".to_string())];
    }
    if let (Some(module), Some(found)) = (&plan.module, file.module_name())
        && found != *module
    {
        return vec![Row::Error(
            plan.path.clone(),
            format!("unexpected module {found}"),
        )];
    }
    let _ = ctx;
    let abs = applied.repo_root.join(&plan.path);
    place_units(plan, text, &abs, applied)
}

/// Presence-gated, gate-deferred, stale-aware placement of one file,
/// applied as sequential splices.
fn place_units(plan: &FilePlan, text: &str, abs: &Path, applied: &mut Applied) -> Vec<Row> {
    let mut current = text.to_string();
    let mut placed: Vec<UnitId> = Vec::new();
    let mut blocked: Vec<String> = Vec::new();
    let mut deferred: Vec<(String, Vec<String>)> = Vec::new();
    let mut stale: Vec<(String, Vec<String>)> = Vec::new();

    for unit in &plan.units {
        // a unit's check reads the file as it stands after earlier inserts,
        // so each check sees the units that already landed
        let file = ElixirFile::parse(&current);
        if !(unit.check)(&file) {
            let unmet: Vec<(String, String)> = unit
                .requires
                .iter()
                .filter(|(path, _)| !applied.existing(path))
                .cloned()
                .collect();
            if !unmet.is_empty() {
                deferred.push((
                    unit.id.label(),
                    unmet.iter().map(|(_, r)| r.clone()).collect(),
                ));
                continue;
            }
            if let Some(stale_fn) = &unit.stale {
                let details = stale_fn(&file);
                if !details.is_empty() {
                    stale.push((unit.id.label(), details));
                    continue;
                }
            }
            let unit_text = (unit.render)();
            match unit.place.apply(&file, &unit_text) {
                Some(next) => {
                    current = next;
                    placed.push(unit.id.clone());
                }
                None => blocked.push(unit.id.label()),
            }
        }
    }

    if placed.is_empty() && deferred.is_empty() && stale.is_empty() && blocked.is_empty() {
        // everything the plan wants is already there — the unchanged
        // early return
        return vec![Row::Unchanged(plan.path.clone())];
    }

    // a test file is created by the first contributor that has a describe
    let describe_landed = placed.iter().any(|id| matches!(id, UnitId::Describe(_)));
    let content =
        !placed.is_empty() && (!applied.creating || !plan.requires_describe || describe_landed);

    let deferred_reasons: Vec<String> = deferred.iter().flat_map(|(_, r)| r.clone()).collect();
    let stale_rows: Vec<Row> = if stale.is_empty() {
        Vec::new()
    } else {
        vec![Row::Stale(
            plan.path.clone(),
            stale
                .iter()
                .flat_map(|(label, details)| details.iter().map(move |d| format!("{label}: {d}")))
                .collect(),
        )]
    };
    let deferred_rows: Vec<Row> = if deferred.is_empty() {
        Vec::new()
    } else {
        vec![Row::Deferred(plan.path.clone(), deferred_reasons.clone())]
    };

    if applied.dry_run {
        if applied.creating {
            // a missing file is reported whole only if the run would really
            // write it: waiting units are a deferral, not a creation
            if content {
                // the whole file plus, for --verbose, the units it carries
                let mut ids = vec![CheckId::WholeFile];
                ids.extend(ids_for_check(&placed, &blocked, &deferred, &stale));
                return vec![Row::Checked(plan.path.clone(), ids)];
            }
            if !deferred.is_empty() {
                let mut rows = deferred_rows;
                rows.extend(stale_rows);
                return rows;
            }
        }
        let ids = ids_for_check(&placed, &blocked, &deferred, &stale);
        return vec![Row::Checked(plan.path.clone(), ids)];
    }

    if !content && blocked.is_empty() {
        // nothing to append: the units either wait for a citizen (deferred)
        // or need a human edit inside an existing line (stale)
        let mut rows = deferred_rows;
        rows.extend(stale_rows);
        return rows;
    }

    if content {
        write_file(abs, &current);
        applied.planned.insert(plan.path.clone());
    }

    let labels: Vec<String> = placed.iter().map(UnitId::label).collect();
    let mut rows: Vec<Row> = if content {
        if applied.creating {
            vec![Row::Created(plan.path.clone())]
        } else if applied.merge_only {
            vec![Row::Backfill(plan.path.clone(), labels)]
        } else {
            vec![Row::Merged(plan.path.clone(), labels)]
        }
    } else if blocked.is_empty() {
        Vec::new()
    } else {
        vec![Row::Blocked(plan.path.clone(), blocked.clone())]
    };
    if !blocked.is_empty() && content {
        rows.push(Row::Blocked(plan.path.clone(), blocked));
    }
    rows.extend(deferred_rows);
    rows.extend(stale_rows);
    rows
}

fn ids_for_check(
    placed: &[UnitId],
    blocked: &[String],
    deferred: &[(String, Vec<String>)],
    stale: &[(String, Vec<String>)],
) -> Vec<CheckId> {
    let mut ids: Vec<CheckId> = placed.iter().map(|u| CheckId::Placed(u.label())).collect();
    ids.extend(blocked.iter().map(|b| CheckId::Unplaceable(b.clone())));
    ids.extend(
        deferred
            .iter()
            .map(|(label, reasons)| CheckId::Deferred(label.clone(), reasons.clone())),
    );
    ids.extend(
        stale
            .iter()
            .map(|(label, details)| CheckId::Stale(label.clone(), details.clone())),
    );
    ids
}

fn write_file(path: &Path, content: &str) {
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    std::fs::write(path, content).expect("write generated file");
}

// ------------------------------------------------- neighborhood closure

/// Creating a citizen flips gates across its constituent: re-apply every
/// neighborhood generator's plans merge-only (existing files only) until a
/// round places nothing. The first round is a full pass — that is what
/// keeps `pickup` honest: a tree a human edited gets every deferred unit
/// re-checked, everywhere.
fn closure_rounds(
    model: &Model,
    seed_ctx: &Context,
    ctx_opts: &ContextOptions,
    applied: &mut Applied,
) -> Vec<Row> {
    let sweep: Vec<Rc<SweepGroup>> = build_sweep(model, seed_ctx, ctx_opts);
    applied.merge_only = true;

    let mut acc: Vec<Row> = Vec::new();
    let mut candidates: Vec<Rc<SweepGroup>> = sweep.clone();
    for _round in 0..MAX_CLOSURE_ROUNDS {
        let mut rows: Vec<Row> = Vec::new();
        let mut changed: HashSet<String> = HashSet::new();
        for group in &candidates {
            let mut group_rows = Vec::new();
            for (plan, ctx) in &group.plans {
                group_rows.extend(apply_plan_merge_only(plan, ctx, applied));
            }
            let reported: Vec<Row> = group_rows
                .into_iter()
                .filter(|r| !matches!(r, Row::Unchanged(_)))
                .collect();
            for row in &reported {
                match row {
                    Row::Backfill(path, _) | Row::Created(path) | Row::Rewritten(path) => {
                        changed.insert(path.clone());
                    }
                    _ => {}
                }
            }
            rows.extend(reported);
        }
        if changed.is_empty() {
            break;
        }
        // later rounds re-apply only the groups whose watched paths changed
        candidates = sweep
            .iter()
            .filter(|g| g.watches.iter().any(|w| changed.contains(w)))
            .cloned()
            .collect();
        if candidates.is_empty() {
            acc.extend(rows);
            break;
        }
        acc.extend(rows);
    }

    applied.merge_only = false;

    // rounds repeat unmet gates while they wait; keep the most recent
    // (smallest) deferred report per file
    let mut seen: HashSet<String> = HashSet::new();
    let mut deduped: Vec<Row> = Vec::new();
    for row in acc.into_iter().rev() {
        if let Row::Deferred(path, _) = &row {
            if seen.contains(path) {
                continue;
            }
            seen.insert(path.clone());
        }
        deduped.push(row);
    }
    deduped.reverse();
    deduped
}

const MAX_CLOSURE_ROUNDS: usize = 3;

struct SweepGroup {
    plans: Vec<(FilePlan, Context)>,
    watches: Vec<String>,
}

/// Every generator that accepts a neighborhood element, with its plans
/// already expanded and its gates frozen into the plan data (Rust plans
/// are per-context by construction). Memoized across rounds of one run
/// because the same groups are re-applied; not memoized across processes
/// — a CLI run is one process.
fn build_sweep(model: &Model, seed: &Context, ctx_opts: &ContextOptions) -> Vec<Rc<SweepGroup>> {
    let constituent = &seed.constituent;
    let mut elements: Vec<Element> = Vec::new();
    for e in &model.elements {
        let included = match e.kind {
            ElementKind::Aggregate => &e.name == constituent,
            ElementKind::Command | ElementKind::Event => e
                .aggregate_name()
                .map(|a| a == constituent)
                .unwrap_or(false),
            ElementKind::Query => e
                .read_model_name()
                .map(|r| r == constituent)
                .unwrap_or(false),
            ElementKind::ReadModel => &e.name == constituent,
            _ => false,
        };
        if included && !elements.iter().any(|x| x.address == e.address) {
            elements.push(e.clone());
        }
    }

    let mut groups = Vec::new();
    for element in elements {
        for blueprint in blueprints::all() {
            if !element_accepted(blueprint, &element) {
                continue;
            }
            let ctx = Context::build(
                model,
                &element,
                &ContextOptions {
                    operation: derive_operation(model, &element),
                    ..ctx_opts.clone_for_sweep()
                },
            );
            let Ok(ctx) = ctx else { continue };
            let plans = plans_for(model, std::slice::from_ref(&blueprint), &ctx);
            let watches = watched_paths(&plans);
            groups.push(Rc::new(SweepGroup { plans, watches }));
        }
    }
    groups
}

/// Every file this plan group reads a gate from, plus the files it writes.
fn watched_paths(plans: &[(FilePlan, Context)]) -> Vec<String> {
    let mut paths: Vec<String> = Vec::new();
    for (plan, _ctx) in plans {
        if !paths.contains(&plan.path) {
            paths.push(plan.path.clone());
        }
        for unit in &plan.units {
            for (gate, _) in &unit.requires {
                if !paths.contains(gate) {
                    paths.push(gate.clone());
                }
            }
        }
        for (gate, _) in &plan.gate {
            if !paths.contains(gate) {
                paths.push(gate.clone());
            }
        }
    }
    paths
}

fn apply_plan_merge_only(plan: &FilePlan, ctx: &Context, applied: &mut Applied) -> Vec<Row> {
    if plan.projection {
        // the merge-only sweep never re-renders a projection: it lands on
        // its own generator's run
        return Vec::new();
    }
    let saved = applied.creating;
    applied.creating = false;
    let abs = ctx.repo_root.join(&plan.path);
    let rows = match std::fs::read_to_string(&abs) {
        Ok(text) => merge(plan, ctx, &text, applied),
        Err(_) => {
            // the closure never creates
            Vec::new()
        }
    };
    applied.creating = saved;
    rows
}

/// The citizen's rules that no invariant pattern realizes are not an error
/// and generate nothing — so they are named in the report instead of
/// living only in `Context`.
fn unresolved_rows(ctx: &Context) -> Vec<Row> {
    if ctx.unresolved.is_empty() {
        return Vec::new();
    }
    let details = ctx
        .unresolved
        .iter()
        .map(|(name, rule)| {
            let text = if rule.is_empty() {
                String::new()
            } else {
                format!(" — {rule}")
            };
            format!(
                "{name}{text}: no invariant pattern realizes it (implement it by hand — see the validator blueprint)"
            )
        })
        .collect();
    vec![Row::Unresolved(
        format!(
            "{}.{}",
            ElementKind::as_str(&ctx.element.kind),
            ctx.element.name
        ),
        details,
    )]
}

/// Effect-bearing runs report open questions instead of inventing answers:
/// an event the read model never decided on generates no projector clause
/// and no aggregate fold — the gap is stated until a declaration closes it.
fn effect_gap_rows(model: &Model, ctx: &Context) -> Vec<Row> {
    match ctx.element.kind {
        ElementKind::Event => {
            if ctx.effect_for_event(&ctx.element.name).is_none() {
                vec![Row::Unresolved(
                    ctx.element.address.clone(),
                    vec![effect_gap_text(&ctx.element.name)],
                )]
            } else {
                Vec::new()
            }
        }
        ElementKind::Aggregate => {
            let details: Vec<String> = model
                .events_of(&ctx.element.name)
                .into_iter()
                .filter(|e| ctx.effect_for_event(&e.name).is_none())
                .map(|e| effect_gap_text(&e.name))
                .collect();
            if details.is_empty() {
                Vec::new()
            } else {
                vec![Row::Unresolved(ctx.element.address.clone(), details)]
            }
        }
        _ => Vec::new(),
    }
}

/// The gap wording.
fn effect_gap_text(event_name: &str) -> String {
    format!(
        "no operation declared by the read model for {event_name} — metadata.annotations.spgen.operation.{event_name} (create|update|delete|none) decides materialization; projector clause and apply fold skipped"
    )
}

pub fn render_report(rows: &[Row], verbose: bool) -> Vec<String> {
    report::render(rows, verbose)
}

// small helper kept next to the engine so every closure round rebuilds a
// location-preserving context without a template-driven operation
impl ContextOptions {
    pub(crate) fn clone_for_sweep(&self) -> ContextOptions {
        ContextOptions {
            operation: None,
            subdomain: self.subdomain.clone(),
            composite: self.composite.clone(),
            constituent: self.constituent.clone(),
            repo_root: self.repo_root.clone(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use std::path::PathBuf;

    /// The fixture corpus with one annotation key removed from the widget
    /// read model — the run then faces an event the read model never
    /// decided on, the case the fixture corpus itself does not hold (every
    /// widget event is declared). The copy is mounted under a
    /// `domain-model` segment so location inference still works.
    fn corpus_missing_effect(key: &str) -> (Model, PathBuf) {
        let fixtures =
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let tmp = std::env::temp_dir().join(format!(
            "sparch-engine-gap-{}-{key}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let root = tmp.join("domain-model");
        copy_tree(&fixtures.canonicalize().unwrap(), &root);
        let read_model = root.join("catalog/equipment/read-model.widget.esdm.yaml");
        let text = std::fs::read_to_string(&read_model).unwrap();
        let stripped: String = text
            .lines()
            .filter(|line| !line.trim_start().starts_with(&format!("{key}:")))
            .collect::<Vec<_>>()
            .join("\n");
        std::fs::write(&read_model, format!("{stripped}\n")).unwrap();
        let model = Model::load(&root);
        (model, tmp)
    }

    fn copy_tree(from: &Path, to: &Path) {
        std::fs::create_dir_all(to).unwrap();
        for entry in std::fs::read_dir(from).unwrap() {
            let entry = entry.unwrap();
            let target = to.join(entry.file_name());
            if entry.path().is_dir() {
                copy_tree(&entry.path(), &target);
            } else {
                std::fs::copy(entry.path(), &target).unwrap();
            }
        }
    }

    fn ctx_for(model: &Model, name: &str, kind: ElementKind) -> Context {
        let element = model.resolve(name, &[kind]).unwrap();
        Context::build(model, &element, &ContextOptions::default()).unwrap()
    }

    #[test]
    fn a_declared_event_reports_no_gap() {
        // the untouched fixture corpus: every widget event is declared, so
        // neither an aggregate run nor an event run states a gap
        let fixtures =
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&fixtures.canonicalize().unwrap());
        let agg = ctx_for(&model, "widget", ElementKind::Aggregate);
        assert!(effect_gap_rows(&model, &agg).is_empty());
        let ev = ctx_for(&model, "widget-created", ElementKind::Event);
        assert!(effect_gap_rows(&model, &ev).is_empty());
    }

    #[test]
    fn an_aggregate_run_states_the_gap_of_an_undeclared_event() {
        let (model, root) = corpus_missing_effect("spgen.operation.widget-archived");
        let agg = ctx_for(&model, "widget", ElementKind::Aggregate);
        let rows = effect_gap_rows(&model, &agg);
        assert_eq!(rows.len(), 1, "only the undeclared event is missing");
        if let Row::Unresolved(address, details) = &rows[0] {
            // the row hangs on the aggregate's own address
            assert_eq!(address, &agg.element.address);
            assert_eq!(details.len(), 1);
            assert_eq!(details[0], effect_gap_text("widget-archived"));
        } else {
            panic!("expected an Unresolved gap row, got {rows:?}");
        }
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn an_undeclared_event_run_states_its_own_gap() {
        let (model, root) = corpus_missing_effect("spgen.operation.widget-archived");
        let ev = ctx_for(&model, "widget-archived", ElementKind::Event);
        let rows = effect_gap_rows(&model, &ev);
        assert_eq!(rows.len(), 1);
        if let Row::Unresolved(address, details) = &rows[0] {
            assert_eq!(address, &ev.element.address);
            assert_eq!(details, &vec![effect_gap_text("widget-archived")]);
        } else {
            panic!("expected an Unresolved gap row, got {rows:?}");
        }
        // the effect is genuinely undecided, not merely reported
        assert!(ev.effect_for_event("widget-archived").is_none());
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn an_invalid_effect_is_undecided_and_states_the_gap() {
        // a typo in the vocabulary is an open question, not a reading
        // exercise: `effect_for_event` reads `:invalid` as `nil`
        let fixtures =
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let tmp = std::env::temp_dir().join(format!(
            "sparch-engine-bad-{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let root = tmp.join("domain-model");
        copy_tree(&fixtures.canonicalize().unwrap(), &root);
        let read_model = root.join("catalog/equipment/read-model.widget.esdm.yaml");
        let text = std::fs::read_to_string(&read_model).unwrap();
        let fixed = text.replace(
            "spgen.operation.widget-archived: delete",
            "spgen.operation.widget-archived: archive",
        );
        std::fs::write(&read_model, fixed).unwrap();
        let model = Model::load(&root);
        let agg = ctx_for(&model, "widget", ElementKind::Aggregate);
        let rows = effect_gap_rows(&model, &agg);
        assert_eq!(rows.len(), 1, "an invalid declaration reports as undecided");
        let _ = std::fs::remove_dir_all(&tmp);
    }

    // -------------------------------------------------------- validate hook

    /// A blueprint exporting `validate` aborts the run before anything is
    /// planned or written, with the model-needs-fixing message shape.
    struct ModelGated;

    impl crate::plan::Blueprint for ModelGated {
        fn name(&self) -> &'static str {
            "gate_check"
        }
        fn source_kinds(&self) -> Vec<ElementKind> {
            vec![ElementKind::Command]
        }
        fn plans(&self, _ctx: &Context) -> Vec<crate::plan::FilePlan> {
            unreachable!("a refused model never plans")
        }
        fn validate(&self, _ctx: &Context) -> Result<(), Vec<String>> {
            Err(vec![
                "constraint valid-slug names no field the model states".to_string(),
                "second gap".to_string(),
            ])
        }
    }

    fn gate_repo(tag: &str) -> PathBuf {
        let fixtures =
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let tmp = std::env::temp_dir().join(format!("sparch-engine-{tag}-gate"));
        // a rerun must start clean: stale generated files from a previous
        // pass would read `Unchanged`, not `Created`
        let _ = std::fs::remove_dir_all(&tmp);
        copy_tree(
            &fixtures.canonicalize().unwrap(),
            &tmp.join("docs/domain-model"),
        );
        tmp
    }

    #[test]
    fn a_failing_model_gate_aborts_the_run_with_every_message() {
        let root = gate_repo("failing");
        let gate: &dyn crate::plan::Blueprint = &ModelGated;
        let opts = crate::engine::RunOptions {
            root: Some(root.display().to_string()),
            ..Default::default()
        };
        let err = run(std::slice::from_ref(&gate), &opts, "create-widget", &root)
            .expect_err("the gate refuses");
        assert_eq!(
            err,
            "gate_check :command.create-widget cannot generate — the model needs fixing:\nconstraint valid-slug names no field the model states\nsecond gap"
        );
        // nothing was written: refusal is before planning
        assert!(!root.join("services").exists());
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn a_blueprint_without_the_gate_runs_on() {
        // the default `validate` (Ok) means the blueprint gates nothing:
        // the same run with a real blueprint passes the hook untouched
        let root = gate_repo("passing");
        let cmd: &dyn crate::plan::Blueprint = &crate::blueprints::command::Command;
        let opts = crate::engine::RunOptions {
            root: Some(root.display().to_string()),
            ..Default::default()
        };
        let rows = run(std::slice::from_ref(&cmd), &opts, "create-widget", &root)
            .expect("the default gate continues the run");
        assert!(
            rows.iter()
                .any(|r| matches!(r, Row::Created(p) if p.ends_with("operations/create_widget/command.ex"))),
            "the run planned and wrote: {rows:?}"
        );
        let _ = std::fs::remove_dir_all(&root);
    }
}
