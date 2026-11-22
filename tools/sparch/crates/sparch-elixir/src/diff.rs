//! The structural model-vs-code diff behind `--diff`.
//!
//! A generator run asks "is this unit present" and stops there, so content
//! that drifted after placement stays invisible. The diff goes one step
//! further: it pairs each unit with the code in the file by the identity of
//! the unit's own render — every blueprint already declares `render`, so no
//! blueprint changes are needed — and compares the two by token signature
//! (`ElixirFile::signature`), which is immune to `mix format` layout,
//! comments, and formatter-inserted trailing commas.
//!
//! The report is a decision record, not a patch: each entry names the unit,
//! the status (`added`, `changed`, `removed`, `deferred`, `blocked`, whole
//! `added`/`rewrite`/`deferred`), and what to do about it. Nothing is ever
//! written. Files that match the model produce no row; a run of
//! `Row::Drift` rows exits 3.
//!
//! Comparison rules the architecture forces:
//!
//! - A unit whose render carries a `TODO:` marker is a human completion
//!   slot (handler and query bodies, prose stubs). Its presence is reported,
//!   its content is never drift.
//! - `describe` blocks are test homes; implement workers add tests inside
//!   them, so they compare by presence only.
//! - `removed` is reported only for families the generator owns outright:
//!   registry entries (`field`, `dispatch`, …), route verbs, `apply/2` and
//!   `authorize/3` clauses, and supervisor children. Directives, attributes
//!   and describes are excluded because files legitimately hold more of
//!   those than the model declares.
//! - Gates are answered from the plan union, not from disk alone: a file
//!   another member of the same suite run would create satisfies the gate,
//!   so a suite diff on a clean tree reports `added` where a pass-through
//!   dry run would report `deferred`.

use std::collections::{BTreeMap, HashMap, HashSet};
use std::path::Path;

use crate::context::Context;
use crate::elixir::{ElixirFile, Identity};
use crate::engine::Row;
use crate::plan::{FilePlan, Unit};

/// Entry families whose surplus in a file is drift the model can delete.
const OWNED_ENTRY_MACROS: &[&str] = &[
    "field",
    "validates",
    "dispatch",
    "identify",
    "project",
    "middleware",
    "router",
    "tags",
    "get",
    "post",
    "put",
    "patch",
    "delete",
];

/// Clause families whose surplus clauses are drift the model can delete.
const OWNED_DEF_FAMILIES: &[&str] = &["apply", "authorize"];

/// One planned unit with the diff's reads of its render, computed once.
struct Planned<'a> {
    label: String,
    render: String,
    render_sig: String,
    identities: Vec<Identity>,
    unit: &'a Unit,
}

/// Diffs the plans against the files on disk. `plans` is the union of every
/// generator and suite member in the run; grouping by path merges the
/// shared files so a unit that several members place is asked once.
pub fn run(plans: &[(FilePlan, Context)], repo_root: &Path, verbose: bool) -> Vec<Row> {
    let mut by_path: BTreeMap<&str, Vec<(&FilePlan, &Context)>> = BTreeMap::new();
    for (plan, ctx) in plans {
        by_path
            .entry(plan.path.as_str())
            .or_default()
            .push((plan, ctx));
    }
    let union: HashSet<&str> = by_path.keys().copied().collect();

    let mut rows = Vec::new();
    for (path, grouped) in by_path {
        let path_plans: Vec<&FilePlan> = grouped.iter().map(|(plan, _)| *plan).collect();
        // The removed scan asks a file for content no planned unit claims.
        // That is only sound where the planned elements own the file: a
        // registration host (application `router` lines, supervisor
        // children, the composite's command router) also carries lines
        // belonging to elements this run does not plan, and "delete it"
        // there would be advice against somebody else's citizen.
        let owns_file = grouped
            .iter()
            .all(|(_, ctx)| path.contains(ctx.constituent.as_str()));
        let text = std::fs::read_to_string(repo_root.join(path)).ok();
        let projection = path_plans.iter().copied().find(|p| p.projection);
        if let Some(plan) = projection {
            rows.extend(projection_diff(
                plan,
                path,
                text.as_deref(),
                repo_root,
                &union,
            ));
            continue;
        }
        if !path_plans.iter().any(|p| p.format) {
            // create-only text artifacts are never rewritten; only a
            // missing file is something to say
            if text.is_none() {
                rows.push(Row::Drift(
                    path.to_string(),
                    vec!["whole file: added — a rerun writes it".to_string()],
                ));
            }
            continue;
        }
        let Some(text) = text else {
            let mut entries = vec!["whole file: added — a rerun writes it".to_string()];
            if verbose {
                for unit in plan_units(&path_plans) {
                    entries.push(format!("  + {}", unit.label));
                }
            }
            rows.push(Row::Drift(path.to_string(), entries));
            continue;
        };
        let file = ElixirFile::parse(&text);
        if !file.parsed() || file.has_errors() {
            rows.push(Row::Error(path.to_string(), "unparsable".to_string()));
            continue;
        }
        let module = path_plans.iter().find_map(|p| p.module.clone());
        if let (Some(module), Some(found)) = (module, file.module_name())
            && found != module
        {
            rows.push(Row::Error(
                path.to_string(),
                format!("unexpected module {found}"),
            ));
            continue;
        }
        rows.extend(file_diff(
            path,
            &file,
            &path_plans,
            repo_root,
            &union,
            owns_file,
            verbose,
        ));
    }
    rows
}

/// The units of a path's plans, deduped by label and render — the suite
/// union hands the same shared citizen to several members, and identical
/// units from different members are one question.
fn plan_units<'a>(plans: &[&'a FilePlan]) -> Vec<Planned<'a>> {
    let mut out: Vec<Planned> = Vec::new();
    for plan in plans {
        for unit in &plan.units {
            let render = (unit.render)();
            let label = unit.id.label();
            if out
                .iter()
                .any(|p: &Planned| p.label == label && p.render == render)
            {
                continue;
            }
            let rfile = ElixirFile::parse(&render);
            let mut identities: Vec<Identity> = Vec::new();
            if rfile.parsed() && !rfile.has_errors() {
                for (start, end) in rfile.fragment_ranges() {
                    match rfile.identify(start, end) {
                        Some(identity) => identities.push(identity),
                        // a fragment whose statements are not all shapes
                        // the diff can pair stays a presence-only unit
                        None => {
                            identities.clear();
                            break;
                        }
                    }
                }
            }
            let render_sig = rfile.signature(0, usize::MAX);
            out.push(Planned {
                label,
                render,
                render_sig,
                identities,
                unit,
            });
        }
    }
    out
}

/// The presence-checked half: per unit status, then the removed scan.
fn file_diff(
    path: &str,
    file: &ElixirFile,
    plans: &[&FilePlan],
    repo_root: &Path,
    union: &HashSet<&str>,
    owns_file: bool,
    verbose: bool,
) -> Vec<Row> {
    let units = plan_units(plans);
    let claim = Claim::gather(&units);

    let mut entries: Vec<String> = Vec::new();
    let mut notes: Vec<String> = Vec::new();
    let mut consumed: HashSet<(usize, usize)> = HashSet::new();

    for planned in &units {
        if (planned.unit.check)(file) {
            if !owns_file {
                // a registration host (application, routers, supervisor)
                // carries lines of elements this run does not plan; its
                // units compare by presence, never content
                notes.push(format!(
                    "present: {} (presence only — the file hosts other elements too)",
                    planned.label
                ));
                continue;
            }
            if planned.identities.is_empty() {
                notes.push(format!("present: {} (shape not comparable)", planned.label));
                continue;
            }
            let ranges = locate(file, &planned.identities, &consumed);
            if ranges.is_empty() {
                notes.push(format!(
                    "present: {} (nothing in the file to compare)",
                    planned.label
                ));
                continue;
            }
            consumed.extend(ranges.iter().copied());
            if completion_slot(&planned.render) || describes(&planned.identities) {
                notes.push(format!(
                    "present: {} (human-completed content)",
                    planned.label
                ));
                continue;
            }
            let current_sig: String = ranges
                .iter()
                .map(|(start, end)| file.signature(*start, *end))
                .collect::<Vec<String>>()
                .join(" ");
            if current_sig == planned.render_sig {
                notes.push(format!("present: {}", planned.label));
                continue;
            }
            let line = file.line_of(ranges[0].0);
            entries.push(format!("{}: changed", planned.label));
            entries.push(format!("  in file at line {line}:"));
            let current: Vec<String> = ranges
                .iter()
                .map(|(start, end)| file.text_slice(*start, *end).trim_end().to_string())
                .collect();
            for snippet in &current {
                for line_text in snippet.lines() {
                    entries.push(format!("    {line_text}"));
                }
            }
            entries.push("  model says:".to_string());
            for line_text in planned.render.trim_end().lines() {
                entries.push(format!("    {line_text}"));
            }
            entries
                .push("  fix: edit the lines, or delete them and rerun the generator".to_string());
        } else {
            let unmet: Vec<String> = planned
                .unit
                .requires
                .iter()
                .filter(|(gate, _)| {
                    !union.contains(gate.as_str()) && !repo_root.join(gate).exists()
                })
                .map(|(_, reason)| reason.clone())
                .collect();
            if !unmet.is_empty() {
                entries.push(format!(
                    "{}: deferred — waiting for {}",
                    planned.label,
                    unmet.join("; ")
                ));
            } else if planned.unit.place.locate(file, &planned.render).is_none() {
                entries.push(format!("{}: blocked — no home in this file", planned.label));
            } else {
                entries.push(format!("{}: added — a rerun places it", planned.label));
            }
        }
    }

    if owns_file {
        removed_entries(file, &claim, &mut entries);
    }

    if entries.is_empty() {
        return Vec::new();
    }
    if verbose {
        entries.extend(notes);
    }
    vec![Row::Drift(path.to_string(), entries)]
}

/// What the model plans to own in this file, per identity family — the
/// basis of the removed scan, which reports file content of an owned family
/// that no planned unit claims.
struct Claim {
    entry_keys: HashSet<(String, String)>,
    entry_macros: HashSet<String>,
    def_families: HashMap<(String, usize), Vec<Vec<String>>>,
    texts: HashSet<String>,
    owns_children: bool,
}

impl Claim {
    fn gather(units: &[Planned]) -> Claim {
        let mut claim = Claim {
            entry_keys: HashSet::new(),
            entry_macros: HashSet::new(),
            def_families: HashMap::new(),
            texts: HashSet::new(),
            owns_children: false,
        };
        for planned in units {
            for identity in &planned.identities {
                match identity {
                    Identity::Entry {
                        macro_name,
                        key,
                        by_last,
                    } => {
                        let _ = by_last;
                        if OWNED_ENTRY_MACROS.contains(&macro_name.as_str()) {
                            claim.entry_keys.insert((macro_name.clone(), key.clone()));
                            claim.entry_macros.insert(macro_name.clone());
                        }
                    }
                    Identity::Def { name, arity, keys } => {
                        if OWNED_DEF_FAMILIES.contains(&name.as_str()) {
                            claim
                                .def_families
                                .entry((name.clone(), *arity))
                                .or_default()
                                .push(keys.clone());
                        }
                    }
                    Identity::Text { text } => {
                        claim.texts.insert(text.clone());
                        claim.owns_children = true;
                    }
                    Identity::Attr { .. } => {}
                }
            }
        }
        claim
    }
}

/// Report file content of an owned family that the model no longer declares.
fn removed_entries(file: &ElixirFile, claim: &Claim, entries: &mut Vec<String>) {
    for macro_name in &claim.entry_macros {
        for entry in file.calls(macro_name) {
            let key = if crate::elixir::is_route_verb(macro_name) {
                entry.action_key()
            } else {
                entry.first_key()
            };
            if !claim
                .entry_keys
                .contains(&(macro_name.clone(), key.clone()))
            {
                entries.push(format!(
                    "{macro_name} {key}: removed from the model — delete it, or state it in the model"
                ));
            }
        }
    }
    for ((name, arity), planned_keys) in &claim.def_families {
        let family: Vec<(String, usize, Vec<String>, usize, usize)> = file
            .def_clause_list()
            .into_iter()
            .filter(|(n, a, ..)| n == name && a == arity)
            .collect();
        // a clause is claimed when some planned head selects it — the same
        // most-specific-key pairing the locate uses, so a shared argument
        // name (`user`) never claims a clause another action owns
        let claimed_starts: HashSet<usize> = planned_keys
            .iter()
            .flat_map(|keys| clauses_selected(&family, keys))
            .map(|(_, _, _, start, _)| *start)
            .collect();
        for (_, _, keys, start, _) in &family {
            if claimed_starts.contains(start) {
                continue;
            }
            let marker = keys
                .iter()
                .find(|key| {
                    (key.starts_with(':') || key.ends_with("{}")) && !key.starts_with("__MODULE__")
                })
                .cloned()
                .or_else(|| keys.last().cloned())
                .unwrap_or_default();
            entries.push(format!(
                "{name}/{arity} {marker}: removed from the model — delete it, or state it in the model (file line {})",
                file.line_of(*start)
            ));
        }
    }
    if claim.owns_children {
        for (text, start, _end) in file.children_elements() {
            if !claim.texts.contains(&text) {
                entries.push(format!(
                    "{text}: removed from the model — delete it, or state it in the model (file line {})",
                    file.line_of(start)
                ));
            }
        }
    }
}

/// The family clauses a rendered clause head selects. The key that
/// narrows the family the most pairs (`:archive_position`, not `user`,
/// which many clauses share); ties widen together. A render key that no
/// clause holds is dropped, and a render whose every key is unknown to
/// the family selects nothing — the caller reads that as no pairing.
fn clauses_selected<'a>(
    family: &'a [(String, usize, Vec<String>, usize, usize)],
    keys: &[String],
) -> Vec<&'a (String, usize, Vec<String>, usize, usize)> {
    let holders = |key: &String| {
        family
            .iter()
            .filter(|(_, _, file_keys, _, _)| file_keys.iter().any(|fk| fk == key))
            .count()
    };
    let smallest = keys.iter().map(holders).filter(|n| *n > 0).min();
    let Some(min) = smallest else {
        return Vec::new();
    };
    family
        .iter()
        .filter(|clause| {
            keys.iter()
                .any(|key| holders(key) == min && clause.2.iter().any(|fk| fk == key))
        })
        .collect()
}

/// The ranges in `file` that carry the unit's statements. `def` clauses are
/// extended over their `@doc`/`@spec` group; `@` attributes are matched
/// last and only where no other range already covers them, so the docs of a
/// rendered clause never pair twice.
fn locate(
    file: &ElixirFile,
    ids: &[Identity],
    consumed: &HashSet<(usize, usize)>,
) -> Vec<(usize, usize)> {
    let mut ranges: Vec<(usize, usize)> = Vec::new();
    // clauses and entries first — a clause group carries its own docs,
    // and the attribute pass below must not pair a mixed render's `@doc`
    // identity onto some other clause's attribute
    for identity in ids.iter().filter(|id| !matches!(id, Identity::Attr { .. })) {
        match identity {
            Identity::Def { name, arity, keys } => {
                let family: Vec<(String, usize, Vec<String>, usize, usize)> = file
                    .def_clause_list()
                    .into_iter()
                    .filter(|(n, a, ..)| n == name && a == arity)
                    .collect();
                for (_, _, _, start, end) in clauses_selected(&family, keys) {
                    ranges.push(file.absorb_attrs(*start, *end));
                }
            }
            Identity::Entry {
                macro_name,
                key,
                by_last,
            } => {
                for entry in file.calls(macro_name) {
                    let found = if *by_last {
                        entry.action_key()
                    } else {
                        entry.first_key()
                    };
                    if &found == key {
                        ranges.push((entry.start(), entry.end()));
                    }
                }
            }
            Identity::Text { text } => {
                for (element, start, end) in file.children_elements() {
                    if &element == text {
                        ranges.push((start, end));
                    }
                }
            }
            Identity::Attr { .. } => {}
        }
    }
    // attributes second, and only for a render that is pure attributes: a
    // clause's docs travel inside its absorbed group, so pairing a `@doc`
    // identity of a mixed render onto some other clause's attribute would
    // only fetch a wrong partner — a missing doc then reads (correctly)
    // as the clause group differing from the render
    if !ids.iter().any(|id| matches!(id, Identity::Def { .. })) {
        for name in ids.iter().filter_map(|id| match id {
            Identity::Attr { name } => Some(name),
            _ => None,
        }) {
            for (attr, start, end) in file.attribute_entries() {
                if &attr != name {
                    continue;
                }
                let covered = ranges
                    .iter()
                    .chain(consumed.iter())
                    .any(|(s, e)| s <= &start && &end <= e);
                if !covered {
                    ranges.push((start, end));
                    break;
                }
            }
        }
    }
    ranges.sort();
    ranges.dedup();
    // a range fully inside another located range (the absorbed attribute
    // lines of a clause) is not content of its own
    let located = ranges.clone();
    ranges.retain(|(start, end)| {
        !located
            .iter()
            .any(|(outer, inner)| outer < start && end < inner)
    });
    ranges
}

/// A unit whose render carries a scaffold completion marker is a slot the
/// implement worker fills — `TODO:` prose and raises, the handler body's
/// `# implement logic here`. Its content is human territory by design, so
/// presence is all the diff may say about it. New scaffold markers join
/// this list.
fn completion_slot(render: &str) -> bool {
    render.contains("TODO") || render.contains("implement logic here")
}

/// A unit that is one `describe` block — test bodies are where implement
/// workers add their manual cases, so they are presence-only.
fn describes(ids: &[Identity]) -> bool {
    ids.iter().all(|identity| {
        matches!(
            identity,
            Identity::Entry { macro_name, .. } if macro_name == "describe"
        )
    }) && !ids.is_empty()
}

/// Projections are model-owned whole files: compare the token signature of
/// the whole file against the whole scaffold, and let any difference say
/// `rewrite` — a real run replaces the file wholesale.
fn projection_diff(
    plan: &FilePlan,
    path: &str,
    text: Option<&str>,
    repo_root: &Path,
    union: &HashSet<&str>,
) -> Vec<Row> {
    let unmet: Vec<String> = plan
        .gate
        .iter()
        .filter(|(gate, _)| !union.contains(gate.as_str()) && !repo_root.join(gate).exists())
        .map(|(_, reason)| reason.clone())
        .collect();
    if !unmet.is_empty() {
        return vec![Row::Drift(
            path.to_string(),
            vec![format!(
                "whole file: deferred — waiting for {}",
                unmet.join("; ")
            )],
        )];
    }
    let Some(scaffold) = &plan.scaffold else {
        return Vec::new();
    };
    match text {
        None => vec![Row::Drift(
            path.to_string(),
            vec!["whole file: added — a rerun writes the projection".to_string()],
        )],
        Some(text) => {
            let current = ElixirFile::parse(text).signature(0, usize::MAX);
            let model = ElixirFile::parse(scaffold).signature(0, usize::MAX);
            if current == model {
                Vec::new()
            } else {
                vec![Row::Drift(
                    path.to_string(),
                    vec![
                        "whole file: rewrite — model-owned content differs (a rerun replaces the file)"
                            .to_string(),
                    ],
                )]
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::blueprints;
    use crate::engine::{self, RunOptions};
    use std::path::{Path, PathBuf};

    /// A tmp repo holding the fixture corpus under `docs/domain-model` —
    /// the layout `build` infers, the same convention the engine tests use.
    fn repo(tag: &str) -> PathBuf {
        let fixtures =
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let tmp = std::env::temp_dir().join(format!(
            "sparch-diff-{tag}-{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        std::fs::create_dir_all(tmp.join("docs")).unwrap();
        copy_tree(
            &fixtures.canonicalize().unwrap(),
            &tmp.join("docs/domain-model"),
        );
        tmp
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

    fn opts(root: &Path) -> RunOptions {
        RunOptions {
            root: Some(root.display().to_string()),
            ..Default::default()
        }
    }

    fn generate(root: &Path, generator: &str, element: &str) -> Vec<Row> {
        let modules = blueprints::generator_modules(generator);
        engine::run(&modules, &opts(root), element, root).expect("the run writes")
    }

    fn diff(root: &Path, generator: &str, element: &str) -> Vec<Row> {
        let modules = blueprints::generator_modules(generator);
        let o = RunOptions {
            diff: true,
            ..opts(root)
        };
        engine::run(&modules, &o, element, root).expect("the diff reads")
    }

    fn drift_entries(rows: &[Row]) -> Vec<(String, Vec<String>)> {
        rows.iter()
            .filter_map(|r| match r {
                Row::Drift(path, entries) => Some((path.clone(), entries.clone())),
                _ => None,
            })
            .collect()
    }

    fn read(root: &Path, path: &str) -> String {
        std::fs::read_to_string(root.join(path)).expect("generated file")
    }

    fn write(root: &Path, path: &str, text: &str) {
        std::fs::write(root.join(path), text).expect("rewrite fixture file");
    }

    fn first_field_line(text: &str) -> String {
        text.lines()
            .find(|line| line.trim_start().starts_with("field :"))
            .expect("the read model has fields")
            .to_string()
    }

    #[test]
    fn a_fresh_generation_diffs_clean() {
        let root = repo("clean");
        let rows = generate(&root, "read_model", "widget");
        assert!(
            rows.iter().any(|r| matches!(r, Row::Created(_))),
            "the run created the citizen: {rows:?}"
        );
        let rows = diff(&root, "read_model", "widget");
        let drift = drift_entries(&rows);
        assert!(drift.is_empty(), "fresh code matches the model: {drift:?}");
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn edited_added_and_surplus_lines_read_changed_added_and_removed() {
        let root = repo("drift");
        generate(&root, "read_model", "widget");
        let path = "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex";
        let created = drift_entries(&generate(&root, "read_model", "widget"));
        assert!(created.is_empty(), "the second run wrote nothing new");
        let original = read(&root, path);
        let field = first_field_line(&original);
        let name = field
            .trim()
            .trim_start_matches("field :")
            .split(',')
            .next()
            .unwrap()
            .to_string();

        // an edited present line is `changed` — the check still passes on
        // the field name, only the content drifted
        let edited = original.replace(&field, &format!("{field}, default: nil"));
        write(&root, path, &edited);
        let entries = drift_entries(&diff(&root, "read_model", "widget"));
        let details: Vec<&String> = entries.iter().flat_map(|(.., e)| e).collect();
        assert!(
            details
                .iter()
                .any(|d| d.starts_with(&format!("field {name}: changed"))),
            "the edited field reads changed: {details:?}"
        );
        assert!(
            details
                .iter()
                .any(|d| d.trim_start().starts_with("model says:")),
            "a changed entry shows what the model says: {details:?}"
        );

        // deleting the line is `added` — a rerun places it back
        let deleted: String = original
            .lines()
            .filter(|line| *line != field)
            .map(|line| format!("{line}\n"))
            .collect();
        write(&root, path, &deleted);
        let entries = drift_entries(&diff(&root, "read_model", "widget"));
        let details: Vec<&String> = entries.iter().flat_map(|(.., e)| e).collect();
        assert!(
            details
                .iter()
                .any(|d| d.starts_with(&format!("field {name}: added"))),
            "the missing field reads added: {details:?}"
        );

        // a surplus field of an owned family is `removed` — the model no
        // longer declares it
        let surplus = original.replace(&field, &format!("{field}\n    field :ghost, :string"));
        write(&root, path, &surplus);
        let entries = drift_entries(&diff(&root, "read_model", "widget"));
        let details: Vec<&String> = entries.iter().flat_map(|(.., e)| e).collect();
        assert!(
            details
                .iter()
                .any(|d| d.starts_with("field :ghost: removed from the model")),
            "the surplus field reads removed: {details:?}"
        );
        // and the untouched fields are not drift
        assert!(
            !details.iter().any(|d| d.contains("changed")),
            "only the ghost drifted: {details:?}"
        );
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn formatting_and_comments_are_not_drift() {
        let root = repo("noise");
        generate(&root, "read_model", "widget");
        let path = "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex";
        let original = read(&root, path);
        let field = first_field_line(&original);
        // what `mix format` and a human leave behind: different indentation
        // and a comment inside a generated block
        let noisy = original.replace(
            &format!("{field}\n"),
            &format!("      # hand note\n        {}\n", field.trim_start()),
        );
        assert_ne!(noisy, original, "the edit changed the bytes");
        write(&root, path, &noisy);
        let drift = drift_entries(&diff(&root, "read_model", "widget"));
        assert!(
            drift.is_empty(),
            "layout and comments are not model drift: {drift:?}"
        );
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn completion_markers_say_which_render_is_human_territory() {
        // a render without a completion marker is model-owned prose; the
        // scaffolded handler body is a slot the worker fills
        assert!(completion_slot(
            "def handle(a, cmd) do\n  # implement logic here\nend"
        ));
        assert!(completion_slot("raise \"TODO: implement\""));
        assert!(!completion_slot(
            "@moduledoc \"\"\"\nProjects facts.\n\"\"\""
        ));
    }

    #[test]
    fn clause_pairing_selects_the_minimally_specific_key() {
        // three clauses of one family, two of one action and one of
        // another, all sharing the argument names `user` and `_p`
        let file = ElixirFile::parse(
            "defmodule P do\n  def authorize(:catalog, user, _p) when is_user?(user), do: :ok\n  def authorize(:archive, user, _p) when is_admin?(user), do: :ok\n  def authorize(:archive, user, _p) when is_user?(user), do: :error\nend\n",
        );
        let family: Vec<_> = file
            .def_clause_list()
            .into_iter()
            .filter(|(n, a, ..)| n == "authorize" && *a == 3)
            .collect();
        // the action atom (2 holders) beats `user` (3 holders): the render
        // pairs its two clauses, never the foreign one
        let selected = clauses_selected(
            &family,
            &[":archive".to_string(), "user".to_string(), "_p".to_string()],
        );
        assert_eq!(selected.len(), 2);
        let selected = clauses_selected(
            &family,
            &[":catalog".to_string(), "user".to_string(), "_p".to_string()],
        );
        assert_eq!(selected.len(), 1);
        // a key no clause holds pairs nothing
        assert!(clauses_selected(&family, &[":ghost".to_string()]).is_empty());
    }

    #[test]
    fn the_union_dissolves_gates_that_alone_defer() {
        // the aggregate run alone leaves its event-gated units deferred;
        // diffed together with the event's own plans — as a suite would —
        // those same units read `added`, because the union creates the gate
        let root = repo("union");
        generate(&root, "aggregate", "widget");

        let agg_modules = blueprints::generator_modules("aggregate");
        let event_modules = blueprints::generator_modules("event");
        let alone = crate::diff::run(
            &engine::build(&agg_modules, &opts(&root), "widget", &root)
                .expect("plans")
                .plans,
            &root,
            false,
        );
        let alone_entries = drift_entries(&alone);
        let alone_details: Vec<&String> = alone_entries.iter().flat_map(|(.., e)| e).collect();
        assert!(
            alone_details.iter().any(|d| d.contains("deferred")),
            "gated units defer alone: {alone_details:?}"
        );

        let mut union = engine::build(&agg_modules, &opts(&root), "widget", &root)
            .expect("plans")
            .plans;
        union.extend(
            engine::build(&event_modules, &opts(&root), "widget-created", &root)
                .expect("plans")
                .plans,
        );
        let merged = crate::diff::run(&union, &root, false);
        let merged_entries = drift_entries(&merged);
        let merged_details: Vec<&String> = merged_entries.iter().flat_map(|(.., e)| e).collect();
        // the gate the union itself writes flips to `added`; the events the
        // union does not plan stay honestly `deferred`
        assert!(
            !merged_details
                .iter()
                .any(|d| d.contains("deferred") && d.contains("widget-created")),
            "the created event is in the union: {merged_details:?}"
        );
        assert!(
            merged_details
                .iter()
                .any(|d| d.starts_with("apply widget-created: added")),
            "the gated clause now reads added: {merged_details:?}"
        );
        assert!(
            merged_details
                .iter()
                .any(|d| d.contains("deferred") && d.contains("widget-archived")),
            "unplanned events keep deferring: {merged_details:?}"
        );
        assert!(
            merged_entries
                .iter()
                .any(|(path, e)| path.ends_with("widget_created.ex")
                    && e.iter().any(|d| d.starts_with("whole file: added"))),
            "the event's own file is part of the union answer: {merged_entries:?}"
        );
        let _ = std::fs::remove_dir_all(&root);
    }
}
