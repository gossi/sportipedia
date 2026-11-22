//! This-model-in, this-file-out acceptance for the FE generators.
//!
//! The frontend sibling of `sparch-elixir`'s `expected_output.rs`: fresh
//! generation only, every created file byte-compared against a flat
//! pattern-named corpus under `tests/expected/` — `domain_object/widget.ts`,
//! `actions/widget.ts`, `fixtures/widgets.ts`, `storybook/equipment-family.ts`.
//!
//! FE specifics:
//! * A scenario is an ordered sequence of runs, not one command: the
//!   engine defers units whose subjects are missing, so a family like
//!   equipment+athlete converges over [instrument, apparatus,
//!   certification, tag, position, apparatus]. Every scenario ends with a
//!   run that defers nothing, and the created set is the diff against the
//!   pristine sandbox over the whole sequence.
//! * Composite-level files (the registration indexes, the composite-wide
//!   storybook) hold whatever the scenario's citizens registered, so they
//!   carry the scenario's driver label in their name; citizen-level
//!   artifacts are stored once and shared — this also proves the
//!   per-artifact runs and the full `feature` run generate the same bytes.
//! * `config.ts` is a spliced human host, not a created file; the BE
//!   policy holds: it stays out of the corpus, covered by `acceptance.rs`.
//!
//! To refresh after a deliberate blueprint change:
//! `SPARCH_UPDATE_EXPECTED=1 cargo test -p sparch-typescript --test expected_files`
//! then review `git diff`. Nothing that fails to parse is ever written.

mod common;

use std::collections::BTreeMap;
use std::path::Path;

use common::{
    cleanup, expected_root, output_files, parse_problems, read, sandbox, sparch, update_requested,
};

/// One scenario: a stable id, the driver label for its composite-level
/// files, and the ordered CLI runs that converge it.
struct Scenario {
    id: &'static str,
    driver: &'static str,
    runs: &'static [&'static [&'static str]],
}

const SCENARIOS: &[Scenario] = &[
    // per-artifact runs on the ungated widget citizen: each blueprint's
    // standalone output. (endpoints, ability-test and storybook gate on
    // citizens the widget feature run already provides — the `widget` row
    // covers those three.)
    Scenario {
        id: "domain-object.widget",
        driver: "widget",
        runs: &[&["domain-object", "widget"]],
    },
    Scenario {
        id: "schema.widget",
        driver: "widget",
        runs: &[&["schema", "widget"]],
    },
    Scenario {
        id: "actions.widget",
        driver: "widget",
        runs: &[&["actions", "widget"]],
    },
    Scenario {
        id: "queries.widget",
        driver: "widget",
        runs: &[&["queries", "widget"]],
    },
    Scenario {
        id: "abilities.widget",
        driver: "widget",
        runs: &[&["abilities", "widget"]],
    },
    Scenario {
        id: "fixtures.widget",
        // its support index carries only the fixtures block — a different
        // bytes than the full widget feature run's
        driver: "widget-fixtures",
        runs: &[&["fixtures", "widget"]],
    },
    Scenario {
        id: "widget",
        driver: "widget",
        runs: &[&["feature", "widget"]],
    },
    // the equipment+athlete family: belongs_to with a column override
    // (position → installed_instrument_id), has_one/has_one inverses, a
    // plain many_to_many pair (apparatus ↔ tag) and a join-model
    // many_to_many (tag ↔ exercise via exercise-tag)
    Scenario {
        id: "family.equipment-athlete",
        driver: "family",
        runs: &[
            &["feature", "instrument"],
            &["feature", "apparatus"],
            &["feature", "apparatus-certification"],
            &["feature", "tag"],
            &["feature", "position"],
            &["feature", "apparatus"],
        ],
    },
    // the exercises composite: two edges to one target with a column
    // override, and the join-model side
    Scenario {
        id: "family.exercises",
        driver: "family",
        runs: &[&["feature", "exercise"], &["feature", "exercise-tag"]],
    },
];

/// The corpus entry for one created file: `category/<name>.ts`. `None`
/// means no rule covers the path — a loud test failure, so the table below
/// stays the complete record of where generated code lives.
fn pattern_name(rel: &str, driver: &str) -> Option<String> {
    let segs: Vec<&str> = rel.split('/').collect();
    if segs.len() < 4 {
        return None;
    }
    let file = *segs.last()?;
    let parent = segs[segs.len() - 2];
    let grand = segs.get(segs.len().checked_sub(3)?);

    // composite-level registrations: bytes depend on what the scenario
    // registered, so the driver label is part of the name
    if file == "index.ts" && parent == "support" {
        return Some(format!("registration/support-{}-{driver}.ts", grand?));
    }
    if file == "index.ts" && segs[2] == "src" {
        return Some(format!("registration/src-{parent}-{driver}.ts"));
    }
    if file == "storybook.ts" && parent == "support" {
        return Some(format!("storybook/{}-{driver}.ts", grand?));
    }

    // composite-level support trees, one file per citizen (by plural).
    // `index.ts` under support is the registration barrel, handled above;
    // a `fixtures/index.ts` under any other directory is a human host.
    if file != "index.ts" && parent == "fixtures" && *grand? == "support" && segs[2] == "tests" {
        return Some(format!("fixtures/{file}"));
    }
    if file != "index.ts" && parent == "queries" && *grand? == "support" && segs[2] == "tests" {
        return Some(format!("endpoints/{file}"));
    }

    // citizen files
    if file == "abilities.test.ts" {
        return Some(format!("ability_test/{parent}.ts"));
    }
    if parent == "schemas" {
        return Some(format!("schema/{file}"));
    }
    if let Some(pos) = segs.iter().position(|s| *s == "domain-objects") {
        // domain-objects/<obj>/... — the obj directory names the citizen;
        // tests never nest deeper, so the next-but-one segment is the file's
        // owner only when it is a leaf module dir
        if pos + 2 == segs.len() - 1 {
            let obj = segs[pos + 1];
            if file == format!("{obj}.ts") {
                return Some(format!("domain_object/{obj}.ts"));
            }
            for artifact in ["actions", "queries", "abilities"] {
                if file == format!("{artifact}.ts") {
                    return Some(format!("{artifact}/{obj}.ts"));
                }
            }
        }
    }
    None
}

#[test]
fn fresh_generation_matches_the_expected_files() {
    let update = update_requested();

    let results = std::thread::scope(|scope| {
        SCENARIOS
            .iter()
            .map(|scenario| {
                let handle = scope.spawn(move || (scenario.id, run(scenario)));
                handle.join().expect("scenario thread panicked")
            })
            .collect::<Vec<_>>()
    });

    let mut problems: Vec<String> = Vec::new();
    // corpus path -> (bytes, the scenarios that produced them)
    let mut produced: BTreeMap<String, (String, Vec<&'static str>)> = BTreeMap::new();
    for (id, result) in results {
        let scenario = SCENARIOS.iter().find(|s| s.id == id).unwrap();
        match result {
            Err(problem) => problems.push(format!("[{id}] {problem}")),
            Ok(files) => {
                for (rel, content) in files {
                    match pattern_name(&rel, scenario.driver) {
                        Some(name) => match produced.get_mut(&name) {
                            Some((known, ids)) => {
                                if *known != content {
                                    problems.push(format!(
                                        "[{id}] {rel} maps to corpus entry {name}, which holds different bytes from [{first}]",
                                        first = ids[0]
                                    ));
                                }
                                ids.push(id);
                            }
                            None => {
                                produced.insert(name, (content, vec![id]));
                            }
                        },
                        None => problems.push(format!(
                            "[{id}] {rel} was created but no pattern rule names it"
                        )),
                    }
                }
            }
        }
    }

    if update && problems.is_empty() {
        let root = expected_root();
        for entry in std::fs::read_dir(&root).into_iter().flatten().flatten() {
            let _ = std::fs::remove_dir_all(entry.path());
        }
        let mut written = 0;
        for (name, (content, _)) in &produced {
            let path = root.join(name);
            std::fs::create_dir_all(path.parent().unwrap()).unwrap();
            std::fs::write(&path, content).unwrap();
            written += 1;
        }
        eprintln!("wrote {written} corpus files under {}", root.display());
        return;
    }

    let on_disk = read_corpus(&expected_root());
    for (name, (content, ids)) in &produced {
        match on_disk.get(name) {
            None => problems.push(format!(
                "{name} was generated by [{}] but is not committed",
                ids.join(", ")
            )),
            Some(stored) => {
                if stored != content {
                    problems.push(format!("{name} differs:\n{}", show_diff(stored, content)));
                }
            }
        }
    }
    for name in on_disk.keys() {
        if !produced.contains_key(name) {
            problems.push(format!("{name} is committed but no scenario generates it"));
        }
    }

    assert!(
        problems.is_empty(),
        "\n\n{} problem(s) across {} scenarios:\n\n{}",
        problems.len(),
        SCENARIOS.len(),
        problems.join("\n\n")
    );
}

/// One scenario over a fresh sandbox: run its whole sequence, return the
/// created files (path + bytes) after every one has proven it parses.
fn run(scenario: &Scenario) -> Result<Vec<(String, String)>, String> {
    let root = sandbox(scenario.id);
    let before = output_files(&root);
    for (step, args) in scenario.runs.iter().enumerate() {
        let (code, out) = sparch(&root, args);
        if code != 0 {
            cleanup(&root);
            return Err(format!("run {step} ({args:?}) exited {code}:\n{out}"));
        }
        // the sequence's last run must converge: nothing may stay deferred
        if step == scenario.runs.len() - 1 && out.contains("deferred") {
            cleanup(&root);
            return Err(format!("still deferring after the full sequence:\n{out}"));
        }
    }

    let files: Vec<(String, String)> = output_files(&root)
        .difference(&before)
        .map(|rel| (rel.clone(), read(&root, rel)))
        .collect();
    cleanup(&root);

    if files.is_empty() {
        return Err("created no files".to_string());
    }
    // the parse guard: nothing unparseable is ever trusted or written
    let broken: Vec<String> = files
        .iter()
        .filter(|(rel, _)| rel.ends_with(".ts"))
        .filter_map(|(rel, text)| parse_problems(rel, text).map(|why| format!("{rel}: {why}")))
        .collect();
    if !broken.is_empty() {
        return Err(format!("generated files that do not parse: {broken:?}"));
    }
    Ok(files)
}

/// The committed corpus, keyed by pattern name.
fn read_corpus(root: &Path) -> BTreeMap<String, String> {
    let mut map = BTreeMap::new();
    walk(root, root, &mut map);
    map
}

fn walk(dir: &Path, base: &Path, map: &mut BTreeMap<String, String>) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for entry in entries.filter_map(Result::ok) {
        let path = entry.path();
        if path.is_dir() {
            walk(&path, base, map);
        } else if let Ok(rel) = path.strip_prefix(base)
            && let Ok(text) = std::fs::read_to_string(&path)
        {
            map.insert(rel.to_string_lossy().replace('\\', "/"), text);
        }
    }
}

/// A line-by-line view of where a committed file and the generated file part
/// ways, so a CI failure reads without opening the corpus.
fn show_diff(expected: &str, actual: &str) -> String {
    let e: Vec<&str> = expected.lines().collect();
    let a: Vec<&str> = actual.lines().collect();
    let mut out = String::new();
    for i in 0..e.len().max(a.len()) {
        let el = e.get(i).copied().unwrap_or("<missing>");
        let al = a.get(i).copied().unwrap_or("<missing>");
        if el != al {
            out.push_str(&format!("  - {el}\n  + {al}\n"));
        }
    }
    out
}

#[cfg(test)]
mod naming {
    use super::*;

    #[test]
    fn every_created_path_maps_to_a_pattern_name() {
        // citizen artifacts
        assert_eq!(
            pattern_name(
                "apps/catalog/src/equipment/domain-objects/widget/widget.ts",
                "widget"
            )
            .as_deref(),
            Some("domain_object/widget.ts")
        );
        assert_eq!(
            pattern_name(
                "apps/catalog/src/athlete/domain-objects/position/actions.ts",
                "family"
            )
            .as_deref(),
            Some("actions/position.ts")
        );
        assert_eq!(
            pattern_name(
                "apps/catalog/src/equipment/domain-objects/apparatus/abilities.ts",
                "family"
            )
            .as_deref(),
            Some("abilities/apparatus.ts")
        );
        assert_eq!(
            pattern_name("apps/catalog/src/equipment/schemas/apparatus.ts", "family").as_deref(),
            Some("schema/apparatus.ts")
        );
        assert_eq!(
            pattern_name(
                "apps/catalog/tests/equipment/domain-objects/apparatus/abilities.test.ts",
                "family"
            )
            .as_deref(),
            Some("ability_test/apparatus.ts")
        );
        assert_eq!(
            pattern_name(
                "apps/catalog/tests/athlete/support/fixtures/positions.ts",
                "family"
            )
            .as_deref(),
            Some("fixtures/positions.ts")
        );
        assert_eq!(
            pattern_name(
                "apps/catalog/tests/exercises/support/queries/exercises.ts",
                "exercises"
            )
            .as_deref(),
            Some("endpoints/exercises.ts")
        );

        // composite-level files carry the driver label
        assert_eq!(
            pattern_name("apps/catalog/src/equipment/index.ts", "widget").as_deref(),
            Some("registration/src-equipment-widget.ts")
        );
        assert_eq!(
            pattern_name(
                "apps/catalog/tests/equipment/support/index.ts",
                "widget-fixtures"
            )
            .as_deref(),
            Some("registration/support-equipment-widget-fixtures.ts")
        );
        assert_eq!(
            pattern_name("apps/catalog/tests/athlete/support/storybook.ts", "family").as_deref(),
            Some("storybook/athlete-family.ts")
        );

        // hand-authored hosts are not generated citizens
        assert_eq!(pattern_name("apps/catalog/src/config.ts", "widget"), None);
        assert_eq!(
            pattern_name(
                "apps/catalog/tests/user/support/fixtures/index.ts",
                "widget"
            ),
            None
        );
    }

    #[test]
    fn the_support_queries_tree_is_not_the_domain_queries_file() {
        // both are named queries; only one is a citizen artifact
        assert_eq!(
            pattern_name(
                "apps/catalog/src/equipment/domain-objects/widget/queries.ts",
                "widget"
            )
            .as_deref(),
            Some("queries/widget.ts")
        );
        assert_eq!(
            pattern_name(
                "apps/catalog/tests/equipment/support/queries/widgets.ts",
                "widget"
            )
            .as_deref(),
            Some("endpoints/widgets.ts")
        );
    }
}
