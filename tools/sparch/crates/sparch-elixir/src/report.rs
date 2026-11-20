//! The operator-facing report — the port of `SpGen.Report`. Same groups,
//! same labels, same future tense under `--dry-run`, same "a path is stated
//! once, the furthest-along state wins", same `skipped:` notes folded into
//! `Ignored`. The report is how the operator decides what to run next: a
//! deferral is guidance, a block is an error.

use crate::engine::Row;

#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
enum Group {
    Created = 0,
    Updated = 1,
    Rewritten = 2,
    Ignored = 3,
    Outdated = 4,
    Unresolved = 5,
    Blocked = 6,
    Failed = 7,
}

impl Group {
    fn label(self, check: bool) -> &'static str {
        match self {
            Group::Created => {
                if check {
                    "Would create"
                } else {
                    "Created"
                }
            }
            Group::Updated => {
                if check {
                    "Would update"
                } else {
                    "Updated"
                }
            }
            Group::Rewritten => {
                if check {
                    "Would rewrite"
                } else {
                    "Rewritten"
                }
            }
            Group::Ignored => "Ignored",
            Group::Outdated => "Outdated",
            Group::Unresolved => "Unresolved rules",
            Group::Blocked => "Blocked",
            Group::Failed => "Failed",
        }
    }
}

/// project roots are noise in every line; the citizen path behind them is not
const ROOTS: &[&str] = &[
    "services/api/lib/sportipedia/",
    "services/api/lib/sportipedia_web/",
    "services/api/test/sportipedia/",
    "services/api/test/sportipedia_web/",
];

pub fn display_path(path: &str) -> String {
    for root in ROOTS {
        if let Some(rest) = path.strip_prefix(root) {
            return rest.to_string();
        }
    }
    path.to_string()
}

struct Item {
    group: Group,
    path: String,
    details: Vec<String>,
    notes: Vec<String>,
}

pub fn render(rows: &[Row], verbose: bool) -> Vec<String> {
    let check = rows.iter().any(|r| matches!(r, Row::Checked(..)));
    // --verbose under --dry-run: the units behind each Checked row, keyed by
    // path; non-verbose output is byte-identical to the Elixir tool's report
    let mut details: std::collections::BTreeMap<String, Vec<String>> = Default::default();
    if verbose {
        for row in rows {
            if let Row::Checked(path, ids) = row {
                let entry = details.entry(path.clone()).or_default();
                for id in ids {
                    let line = match id {
                        CheckId::Placed(l) => format!("+ {l}"),
                        CheckId::Unplaceable(l) => format!("! {l}: blocked, no home in this file"),
                        CheckId::Deferred(l, reasons) => {
                            format!("~ {l}: waiting for {}", reasons.join("; "))
                        }
                        CheckId::WholeFile => "+ whole file".to_string(),
                        CheckId::Rewrite => "~ whole file (model-owned rewrite)".to_string(),
                        // stale detail belongs to the Outdated group already
                        CheckId::Stale(..) => continue,
                    };
                    if !entry.contains(&line) {
                        entry.push(line);
                    }
                }
            }
        }
    }
    let details = &details;
    let mut items: Vec<Item> = Vec::new();
    for row in rows {
        items.extend(entries(row));
    }

    let mut lines = Vec::new();
    let mut result: Vec<Item> = Vec::new();
    // the write groups reduce to one entry per path across groups — the
    // furthest-along state wins; problems are deduped per (group, path)
    let mut writes: Vec<Item> = Vec::new();
    let mut problems: Vec<Item> = Vec::new();
    for item in items {
        if matches!(
            item.group,
            Group::Created | Group::Updated | Group::Rewritten | Group::Ignored
        ) {
            writes.push(item);
        } else {
            problems.push(item);
        }
    }
    let mut strongest_wins: Vec<Item> = Vec::new();
    // `Report.strongest/1` plus `merge/3`: the strongest group names the
    // path, and the `skipped:` notes of every write row touching it
    // accumulate — a file partly back-filled and partly deferred reads
    // `Updated … skipped:`, not a bare `Updated`.
    for item in writes {
        match strongest_wins.iter_mut().find(|w| w.path == item.path) {
            Some(w) => {
                if item.group < w.group {
                    w.group = item.group;
                }
                w.notes.extend(item.notes);
            }
            None => strongest_wins.push(item),
        }
    }
    result.extend(strongest_wins);
    result.extend(problems);
    for group in [
        Group::Created,
        Group::Updated,
        Group::Rewritten,
        Group::Ignored,
        Group::Outdated,
        Group::Unresolved,
        Group::Blocked,
        Group::Failed,
    ] {
        let mut group_items: Vec<&Item> = result.iter().filter(|i| i.group == group).collect();
        if group_items.is_empty() {
            continue;
        }
        group_items.sort_by_key(|i| display_path(&i.path));
        lines.push(group.label(check).to_string());
        for item in group_items {
            match group {
                Group::Outdated | Group::Unresolved => {
                    lines.push(format!("  {}", display_path(&item.path)));
                    for d in &item.details {
                        lines.push(format!("    - {d}"));
                    }
                }
                _ => {
                    let mut note = String::new();
                    let commands = skipped_commands(&item.notes);
                    if !commands.is_empty() {
                        note = format!("  skipped: {}", commands.join(", "));
                    }
                    lines.push(format!("  {}{note}", display_path(&item.path)));
                    if let Some(unit_lines) = details.get(&item.path) {
                        for d in unit_lines {
                            lines.push(format!("    {d}"));
                        }
                    }
                }
            }
        }
    }
    lines
}

fn entries(row: &Row) -> Vec<Item> {
    let item = |group: Group, path: &str, details: Vec<String>, notes: Vec<String>| Item {
        group,
        path: path.to_string(),
        details,
        notes,
    };
    match row {
        Row::Created(p) => vec![item(Group::Created, p, vec![], vec![])],
        Row::Merged(p, _) | Row::Backfill(p, _) => vec![item(Group::Updated, p, vec![], vec![])],
        Row::Unchanged(p) => vec![item(Group::Ignored, p, vec![], vec![])],
        Row::Rewritten(p) => vec![item(Group::Rewritten, p, vec![], vec![])],
        Row::Deferred(p, reasons) => vec![item(Group::Ignored, p, vec![], reasons.clone())],
        Row::Stale(p, details) => vec![item(Group::Outdated, p, details.clone(), vec![])],
        Row::Unresolved(p, details) => vec![item(Group::Unresolved, p, details.clone(), vec![])],
        Row::Blocked(p, _) => vec![item(Group::Blocked, p, vec![], vec![])],
        Row::Error(p, _) => vec![item(Group::Failed, p, vec![], vec![])],
        Row::Checked(p, ids) => checked_entries(p, ids),
    }
}

/// A dry-run row resolves to the group the generator would produce when
/// it ran — `Report.entries/1` for `{:checked, path, ids}`.
fn checked_entries(path: &str, ids: &[CheckId]) -> Vec<Item> {
    let mut notes: Vec<String> = Vec::new();
    let mut stale_details: Vec<String> = Vec::new();
    let mut has_placeable = false;
    let mut has_unplaceable = false;

    for id in ids {
        match id {
            CheckId::Placed(label) => {
                let _ = label;
                has_placeable = true;
            }
            CheckId::Unplaceable(label) => {
                let _ = label;
                has_unplaceable = true;
            }
            CheckId::Deferred(_, reasons) => {
                notes.extend(reasons.iter().cloned());
            }
            CheckId::Stale(label, details) => {
                stale_details.extend(details.iter().map(|d| format!("{label}: {d}")));
            }
            CheckId::WholeFile | CheckId::Rewrite => {}
        }
    }

    let whole_file = ids.iter().any(|i| matches!(i, CheckId::WholeFile));
    if whole_file {
        return vec![Item {
            group: Group::Created,
            path: path.to_string(),
            details: vec![],
            notes,
        }];
    }
    if ids.iter().any(|i| matches!(i, CheckId::Rewrite)) {
        return vec![Item {
            group: Group::Rewritten,
            path: path.to_string(),
            details: vec![],
            notes,
        }];
    }

    let group = if has_unplaceable {
        Group::Blocked
    } else if has_placeable {
        Group::Updated
    } else {
        Group::Ignored
    };

    let mut out = Vec::new();
    // a check row whose only finding is outdated is not also "nothing here"
    if !(group == Group::Ignored && !stale_details.is_empty()) {
        out.push(Item {
            group,
            path: path.to_string(),
            details: vec![],
            notes,
        });
    }
    if !stale_details.is_empty() {
        out.push(Item {
            group: Group::Outdated,
            path: path.to_string(),
            details: stale_details,
            notes: vec![],
        });
    }
    out
}

/// "validator unique_slug not generated (sparch command)" → "sparch command"
fn skipped_commands(notes: &[String]) -> Vec<String> {
    let mut commands: Vec<String> = Vec::new();
    for note in notes {
        let mut rest = note.as_str();
        while let Some(open) = rest.find("(sparch ") {
            let after = &rest[open + 1..];
            if let Some(close) = after.find(')') {
                let command = after[..close].to_string();
                if !commands.contains(&command) {
                    commands.push(command);
                }
                rest = &after[close..];
            } else {
                break;
            }
        }
    }
    commands.sort();
    commands
}

/// The detail of a dry-run row, resolved to report shapes.
#[derive(Debug, Clone)]
pub enum CheckId {
    WholeFile,
    Rewrite,
    Placed(String),
    Unplaceable(String),
    Deferred(String, Vec<String>),
    Stale(String, Vec<String>),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn groups_print_in_order_and_empty_ones_not_at_all() {
        let lines = render(
            &[
                Row::Unchanged(
                    "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex".into(),
                ),
                Row::Created(
                    "services/api/lib/sportipedia/catalog/equipment/widget/event.ex".into(),
                ),
            ],
            false,
        );
        assert_eq!(
            lines,
            vec![
                "Created",
                "  catalog/equipment/widget/event.ex",
                "Ignored",
                "  catalog/equipment/widget/read_model.ex"
            ]
        );
    }

    #[test]
    fn deferred_files_fold_into_ignored_with_commands() {
        let lines = render(
            &[Row::Deferred(
                "services/api/lib/sportipedia/catalog/equipment/widget/command.ex".into(),
                vec!["validator unique_slug not generated (sparch command)".into()],
            )],
            false,
        );
        assert_eq!(
            lines,
            vec![
                "Ignored",
                "  catalog/equipment/widget/command.ex  skipped: sparch command"
            ]
        );
    }

    #[test]
    fn check_rows_read_in_future_tense() {
        let lines = render(
            &[Row::Checked(
                "services/api/lib/sportipedia/catalog/equipment/widget/view.ex".into(),
                vec![CheckId::WholeFile],
            )],
            false,
        );
        assert_eq!(
            lines,
            vec!["Would create", "  catalog/equipment/widget/view.ex"]
        );
    }

    #[test]
    fn outdated_carries_its_detail_lines() {
        let lines = render(
            &[Row::Stale(
                "services/api/lib/sportipedia/catalog/equipment/widget/controller.ex".into(),
                vec!["validates :slug: add by: [function: &Other.validate/2]".into()],
            )],
            false,
        );
        assert_eq!(
            lines,
            vec![
                "Outdated",
                "  catalog/equipment/widget/controller.ex",
                "    - validates :slug: add by: [function: &Other.validate/2]"
            ]
        );
    }

    #[test]
    fn strongest_state_wins_per_path() {
        let lines = render(
            &[
                Row::Unchanged(
                    "services/api/lib/sportipedia/catalog/equipment/widget/query.ex".into(),
                ),
                Row::Merged(
                    "services/api/lib/sportipedia/catalog/equipment/widget/query.ex".into(),
                    vec![],
                ),
            ],
            false,
        );
        assert_eq!(
            lines,
            vec!["Updated", "  catalog/equipment/widget/query.ex"]
        );
    }

    // `Report.strongest/1` unions the notes across the rows of one path: a
    // file the closure partly back-filled and partly left waiting reads one
    // `Updated … skipped:` line, the way the oracle reports a deferred
    // internal module whose un-gated alias landed.
    #[test]
    fn backfill_and_deferral_union_their_notes_per_path() {
        let lines = render(
            &[
                Row::Backfill(
                    "services/api/lib/sportipedia/catalog/equipment/widget/internal.ex".into(),
                    vec!["alias Sportipedia.Catalog.Repo".into()],
                ),
                Row::Deferred(
                    "services/api/lib/sportipedia/catalog/equipment/widget/internal.ex".into(),
                    vec![
                        "read model not generated (sparch read_model)".into(),
                        "lookup query for slug not generated (sparch internal_api)".into(),
                    ],
                ),
            ],
            false,
        );
        assert_eq!(
            lines,
            vec![
                "Updated",
                "  catalog/equipment/widget/internal.ex  skipped: sparch internal_api, sparch read_model",
            ]
        );
    }

    // The wave-1 unit ids (`{:derive, _}`, `:moduletag`, `{:test_alias, _}`)
    // are not special to the report: labels come from `UnitId::label` (which
    // mirrors `Report.unit_label/1`) and grouping reads only the row shape.
    // A deferred test-file unit folds into `Ignored` with the `skipped:`
    // note, the way every other unit id does.
    #[test]
    fn wave_one_unit_ids_fold_without_special_grouping() {
        use crate::plan::UnitId;
        assert_eq!(
            UnitId::Derive("Jason.Encoder".into()).label(),
            "derive Jason.Encoder"
        );
        assert_eq!(UnitId::Moduletag.label(), "moduletag");
        assert_eq!(
            UnitId::TestAlias("Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated".into())
                .label(),
            "test_alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated"
        );

        let lines = render(
            &[
                Row::Created(
                    "services/api/lib/sportipedia/catalog/equipment/widget/events/widget_created.ex".into(),
                ),
                Row::Deferred(
                    "services/api/test/sportipedia/catalog/equipment/widget/events/widget_created_test.exs".into(),
                    vec!["event not generated (sparch event)".into()],
                ),
            ],
            false,
        );
        assert_eq!(
            lines,
            vec![
                "Created",
                "  catalog/equipment/widget/events/widget_created.ex",
                "Ignored",
                "  catalog/equipment/widget/events/widget_created_test.exs  skipped: sparch event",
            ]
        );
    }
}
