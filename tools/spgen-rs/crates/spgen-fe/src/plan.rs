//! The unit model and merge engine — the FE shape of the BE rules: the
//! unit is the unit of work (identity, presence check, renderer, placement,
//! gate), merging is append-only, deferral is a report not an error, and
//! the tree keeps compiling after every run.

use std::{
    fs,
    path::{Path, PathBuf},
};

use crate::{
    report::Report,
    splices::{self, Splices},
    ts::TsFile,
};

/// How a unit's presence is recognized in an existing file.
#[derive(Clone, Debug)]
pub enum Presence {
    /// A top-level declaration with this name.
    Declaration(String),
    /// `test('<title>'` in the text.
    TestTitle(String),
    /// An import specifier from a source.
    Import {
        source: String,
        type_only: bool,
        specifier: String,
    },
    /// A member of the bracket list at the anchor (`registerResources([`,
    /// `POSITIONS = [`).
    Member { anchor: String, member: String },
    /// A member of the `export { … } from '<source>'` block of a barrel.
    BlockMember { source: String, member: String },
    /// A substring line (the `configureAthleteSchema(store.schema);` call).
    Line(String),
}

/// Where the unit's text goes when it is missing.
#[derive(Clone, Debug)]
pub enum Place {
    /// Append at end of file, separated by a blank line.
    Eof,
    /// Add the specifier to the import for `source` (creating the
    /// statement after the existing block of its kind when absent).
    Import { source: String, type_only: bool },
    /// Append the member to the bracket list at the anchor.
    Member { anchor: String },
    /// Append the member to the barrel's export block for the source; the
    /// unit defers while the block does not exist (the block unit of the
    /// same plan brings it).
    BlockMember { source: String },
    /// Append the unit's text (a whole `export { … } from '…'` block) at
    /// end of file — placed when its presence line is missing.
    AppendText,
    /// Insert the text at the end of the last line matching the first of
    /// `needles` that occurs (sibling anchor, then house anchor); defer
    /// when none does.
    AfterLastLine { needles: Vec<String> },
    /// Insert the text right after the line containing the needle.
    AfterLine { needle: String },
}

#[derive(Clone)]
pub struct Unit {
    pub id: String,
    pub text: String,
    pub presence: Presence,
    pub place: Place,
    /// The comma member to insert, for the member places.
    pub member: Option<String>,
    /// Referenced citizens' files must exist before this unit places;
    /// while any is missing the unit defers (report, exit 0).
    pub gate: Vec<PathBuf>,
    /// Units that ride along: placed only when this unit is actually
    /// added. Imports belong to the code that uses them — attaching them
    /// as companions keeps a present unit from injecting an unused
    /// import into a human file.
    pub companions: Vec<Unit>,
}

impl Unit {
    pub fn with(mut self, companion: Unit) -> Unit {
        self.companions.push(companion);
        self
    }
}

pub struct FilePlan {
    /// Repo-relative path of the target file.
    pub path: PathBuf,
    /// Registration hosts are merge-only and fail loudly when missing;
    /// citizen files are created by the blueprint that writes them.
    pub host: bool,
    /// The full file, used when it does not exist yet.
    pub create: Option<String>,
    /// Units merged into an existing file.
    pub units: Vec<Unit>,
}

pub fn present(ts: &TsFile, presence: &Presence) -> bool {
    match presence {
        Presence::Declaration(name) => ts.declares(name),
        Presence::TestTitle(title) => ts.has_test(title),
        Presence::Import {
            source,
            type_only,
            specifier,
        } => ts.imports_specifier(source, *type_only, specifier),
        Presence::Member { anchor, member } => splices::array_has_member(&ts.text, anchor, member),
        Presence::BlockMember { source, member } => {
            splices::block_has_member(&ts.text, source, member)
        }
        Presence::Line(needle) => ts.text.contains(needle),
    }
}

pub fn gate_open(gate: &[PathBuf], repo_root: &Path) -> bool {
    gate.iter().all(|rel| repo_root.join(rel).exists())
}

/// Merge a plan into an existing file. Returns the added unit ids; an
/// empty result means every unit is already present.
///
/// With `force`, a unit that is present but whose text differs from its
/// fresh rendering is **rewritten in place**: only its own declaration
/// range (plus the comment block directly above it) is replaced — the
/// rest of the file, human or generated, is untouched.
pub fn merge(
    ts: &TsFile,
    units: &[Unit],
    repo_root: &Path,
    force: bool,
) -> Result<Outcome, String> {
    let mut splices = Splices::default();
    let mut added = Vec::new();
    let mut deferred = Vec::new();

    let pass = Pass { repo_root, force };
    for unit in units {
        place_tree(ts, unit, &pass, &mut splices, &mut deferred, &mut added)?;
    }

    Ok(Outcome {
        text: if added.is_empty() {
            None
        } else {
            Some(splices.apply(&ts.text))
        },
        added,
        deferred,
    })
}

/// One merge pass over one file: where the repo is and whether
/// present-but-stale units get rewritten.
struct Pass<'a> {
    repo_root: &'a Path,
    force: bool,
}

/// Presence, gate and placement for one unit; companions — the imports
/// that belong to it — are placed exactly when the unit itself is added,
/// never when it is present, gated away, or deferred. With `force`, a
/// present unit whose text differs from its fresh rendering is rewritten
/// in its own range.
fn place_tree(
    ts: &TsFile,
    unit: &Unit,
    pass: &Pass<'_>,
    splices: &mut Splices,
    deferred: &mut Vec<String>,
    added: &mut Vec<String>,
) -> Result<(), String> {
    if present(ts, &unit.presence) {
        if pass.force
            && let Some((from, to)) = rewrite_range(ts, unit)
        {
            // the range covers the old body exactly (span plus its
            // comment block); the fresh rendering replaces it whole, and
            // the newline that ended the original statement survives
            if ts.text[from..to].trim() != unit.text.trim() {
                splices.replace(from as u32, to as u32, unit.text.trim_end());
                added.push(format!("{} (rewritten)", unit.id));
                for companion in &unit.companions {
                    place_tree(ts, companion, pass, splices, deferred, added)?;
                }
            }
        }
        return Ok(());
    }
    if !gate_open(&unit.gate, pass.repo_root) {
        deferred.push(unit.id.clone());
        return Ok(());
    }
    if place_unit(ts, unit, splices, deferred)? {
        added.push(unit.id.clone());
        for companion in &unit.companions {
            place_tree(ts, companion, pass, splices, deferred, added)?;
        }
    }
    Ok(())
}

/// The byte range a force rewrite replaces: an end-of-file declaration
/// (with its leading comment block) or a `test('title', …)` statement.
/// Membership and import placements carry no body text of their own, so
/// there is nothing to rewrite — force only ensures them.
fn rewrite_range(ts: &TsFile, unit: &Unit) -> Option<(usize, usize)> {
    if !matches!(unit.place, Place::Eof) {
        return None;
    }
    match &unit.presence {
        Presence::Declaration(name) => ts.declaration_span(name).map(|(s, e)| {
            (
                crate::splices::extend_over_leading_comments(&ts.text, s as usize),
                e as usize,
            )
        }),
        Presence::TestTitle(title) => crate::splices::test_statement_range(&ts.text, title),
        _ => None,
    }
}

/// Splice one unit into `splices`. `true` means it placed; `false` means
/// it deferred itself (an anchor or block that is not there yet).
fn place_unit(
    ts: &TsFile,
    unit: &Unit,
    splices: &mut Splices,
    deferred: &mut Vec<String>,
) -> Result<bool, String> {
    match &unit.place {
        Place::Eof => {
            let mut text = String::from("\n\n");
            text.push_str(unit.text.trim_end());
            text.push('\n');
            splices.insert(
                ts.text.len() as u32 - trailing_newlines(&ts.text) as u32,
                text,
            );
        }
        Place::Import { source, type_only } => {
            plan_import(ts, source, *type_only, &unit.text, splices);
        }
        Place::Member { anchor } => {
            let member = unit
                .member
                .clone()
                .ok_or_else(|| format!("unit {} must place a member", unit.id))?;
            if let Some((offset, text)) = splices::insert_into_array(&ts.text, anchor, &member) {
                splices.insert(offset, text);
            } else {
                // the anchor is a structure this very plan can (re-)create
                // — the closure pass back-fills the member once it exists
                deferred.push(format!("{} (anchor pending)", unit.id));
                return Ok(false);
            }
        }
        Place::BlockMember { source } => {
            let member = unit
                .member
                .clone()
                .ok_or_else(|| format!("unit {} must place a block member", unit.id))?;
            match splices::insert_into_block(&ts.text, source, &member) {
                Some((offset, text)) => splices.insert(offset, text),
                // the block arrives with the block unit of this plan (or
                // this pass, via the closure loop) — pending, not failed
                None => {
                    deferred.push(format!("{} (block pending)", unit.id));
                    return Ok(false);
                }
            }
        }
        Place::AppendText => {
            let mut text = String::from("\n");
            text.push_str(unit.text.trim());
            text.push('\n');
            splices.insert(
                ts.text.len() as u32 - trailing_newlines(&ts.text) as u32,
                text,
            );
        }
        Place::AfterLastLine { needles } => {
            let anchored = needles
                .iter()
                .find_map(|needle| splices::after_last_line(&ts.text, needle));
            match anchored {
                Some(offset) => splices.insert(offset as u32, unit.text.clone()),
                None => {
                    deferred.push(format!("{} (no host anchor)", unit.id));
                    return Ok(false);
                }
            }
        }
        Place::AfterLine { needle } => match splices::after_line(&ts.text, needle) {
            Some(offset) => splices.insert(offset as u32, unit.text.clone()),
            // a host whose shape we don't recognize: guide, don't fail,
            // and never write something we cannot prove correct
            None => {
                deferred.push(format!("{} (host anchor missing: {needle})", unit.id));
                return Ok(false);
            }
        },
    }
    Ok(true)
}

pub struct Outcome {
    pub text: Option<String>,
    pub added: Vec<String>,
    pub deferred: Vec<String>,
}

fn trailing_newlines(text: &str) -> usize {
    text.len() - text.trim_end_matches('\n').len()
}

/// Splice a new import specifier, or a fresh import statement if the
/// source is not imported yet. New statements land after the last import
/// of their kind — exact grouping is left to the project's lint phase.
fn plan_import(ts: &TsFile, source: &str, type_only: bool, specifier: &str, edits: &mut Splices) {
    if let Some(import) = ts.import_for(source, type_only)
        && let (Some(open), Some(close)) = (import.brace_open, import.brace_close)
    {
        let inner = ts.text[open as usize..close as usize].trim();
        if inner.is_empty() {
            edits.insert(open + 1, format!(" {specifier} "));
        } else {
            let last = ts.text[..close as usize].trim_end().len();
            edits.insert(last as u32, format!(", {specifier}"));
        }
        return;
    }

    // fresh statement, after the last import of this kind — always on a
    // line of its own: skip past the newline at the anchor when there is
    // one, otherwise open a new line first
    let anchor = ts
        .imports
        .iter()
        .filter(|i| i.type_only == type_only)
        .map(|i| i.statement_end)
        .max()
        .unwrap_or(ts.after_last_import);
    let keyword = if type_only { "import type" } else { "import" };
    let mut at = anchor as usize;
    let mut text = format!("{keyword} {{ {specifier} }} from '{source}';\n");
    if ts.text.as_bytes().get(at) == Some(&b'\n') {
        at += 1;
    } else if at > 0 {
        text.insert(0, '\n');
    }
    edits.insert(at as u32, text);
}

/// Apply one plan: create, merge, or report the deferral/block.
pub fn run_plan(plan: &FilePlan, repo_root: &Path, check: bool, force: bool, report: &mut Report) {
    let abs = repo_root.join(&plan.path);
    let display = plan.path.display().to_string();

    if !abs.exists() {
        if plan.host {
            report.blocked(&display, "registration host missing".into());
            return;
        }
        match &plan.create {
            Some(text) => {
                // A created file must not reference citizens that do not
                // exist yet — the gates of its units decide: while any is
                // closed, the whole file defers and back-fills later.
                let blocked_by: Vec<&Unit> = plan
                    .units
                    .iter()
                    .filter(|u| !gate_open(&u.gate, repo_root))
                    .collect();
                if !blocked_by.is_empty() {
                    let reason = blocked_by[0]
                        .gate
                        .iter()
                        .find(|g| !repo_root.join(g).exists())
                        .map(|g| format!("references {}", g.display()))
                        .unwrap_or_default();
                    report.deferred(&display, format!("{} unit(s): {reason}", blocked_by.len()));
                    return;
                }
                if check {
                    report.would_create(&display);
                } else if create_file(&abs, text, report, &display) {
                    report.created(&display);
                }
            }
            None => {
                let gate = plan
                    .units
                    .first()
                    .and_then(|u| u.gate.first())
                    .map(|g| format!("references {}", g.display()))
                    .unwrap_or_else(|| "subject missing".into());
                report.deferred(&display, gate);
            }
        }
        return;
    }

    let Ok(text) = fs::read_to_string(&abs) else {
        report.failed(&display, "cannot read".into());
        return;
    };
    let Some(mut ts) = TsFile::parse(&display, text) else {
        report.failed(&display, "does not parse".into());
        return;
    };

    // closure pass (BE decision #4 ported): merge, write, re-parse, merge
    // again — units whose anchor or block is created by this very plan
    // back-fill within the same run; the loop ends when the text stops
    // changing (or after a cap, reporting what remains pending)
    let mut added: Vec<String> = Vec::new();
    let mut deferred: Vec<String> = Vec::new();
    let mut failure: Option<String> = None;

    for _round in 0..8 {
        match merge(&ts, &plan.units, repo_root, force) {
            Err(reason) => {
                failure = Some(reason);
                break;
            }
            Ok(outcome) => {
                deferred = outcome.deferred;
                added.extend(outcome.added);
                let Some(new_text) = outcome.text else {
                    break;
                };
                if !check && let Err(e) = fs::write(&abs, &new_text) {
                    failure = Some(format!("cannot write: {e}"));
                    break;
                }
                match TsFile::parse(&display, new_text) {
                    Some(next) => ts = next,
                    None => {
                        failure = Some("merge result does not parse".into());
                        break;
                    }
                }
            }
        }
    }

    if let Some(reason) = failure {
        report.failed(&display, reason);
        return;
    }
    if !deferred.is_empty() {
        report.deferred_units(&display, deferred);
    }
    if added.is_empty() {
        report.ignored(&display);
    } else if check {
        report.would_update(&display, added);
    } else {
        report.updated(&display, added);
    }
}

fn create_file(abs: &Path, text: &str, report: &mut Report, display: &str) -> bool {
    if let Some(parent) = abs.parent()
        && let Err(e) = fs::create_dir_all(parent)
    {
        report.failed(display, format!("cannot create {}: {e}", parent.display()));
        return false;
    }
    match fs::write(abs, text) {
        Ok(()) => true,
        Err(e) => {
            report.failed(display, format!("cannot write: {e}"));
            false
        }
    }
}
