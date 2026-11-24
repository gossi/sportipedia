//! This-model-in, this-file-out acceptance for the BE generators.
//!
//! Each scenario is a fresh generation (`sparch-elixir <generator> <element>`)
//! over the fixture sandbox. Every file a run creates is mapped to a pattern
//! name — `<generator>/<element>.<ext>`, e.g. `command/edit_widget.ex`,
//! `validator/unique_slug.ex` — and compared byte for byte against the
//! committed corpus under `tests/expected/`. The corpus is a flat catalogue
//! of everything the architecture generates: one file per artifact, named by
//! the pattern that produced it, so a directory listing answers "which code
//! is generated, and from what".
//!
//! An artifact several scenarios create is stored once when the bytes agree
//! (this also proves dependency generation equals primary generation); when
//! the driver changes the output — the `feature` suite wires every operation
//! into its citizens, an archive command drives a leaner internal API — each
//! variant lives side by side with a driver suffix (`aggregate/widget-feature.ex`).
//! Only *created* files are tracked; splices into hand-written hosts (router,
//! supervisor) are covered by `acceptance.rs`, not duplicated here.
//!
//! To refresh the corpus after a deliberate blueprint change:
//! `SPARCH_UPDATE_EXPECTED=1 cargo test -p sparch-elixir --test expected_output`
//! then review `git diff`. A file that fails to parse is never written, so a
//! broken generator cannot write its own output into the corpus.

mod common;

use std::collections::BTreeMap;
use std::path::Path;

use common::{cleanup, expected_root, output_files, sandbox, sparch, update_requested};
use sparch_elixir::elixir::ElixirFile;

/// One scenario: a stable id, the CLI argv, and the `owner` used to
/// namespace artifacts more than one blueprint writes to (the domain
/// `operations/*_test.exs` files).
struct Scenario {
    id: &'static str,
    args: &'static [&'static str],
    owner: &'static str,
}

const SCENARIOS: &[Scenario] = &[
    // read models — baseline plus every relation kind the corpus expresses
    Scenario {
        id: "read_model.widget",
        args: &["read_model", "widget"],
        owner: "read_model",
    },
    Scenario {
        id: "read_model.position",
        args: &["read_model", "position"],
        owner: "read_model",
    },
    Scenario {
        id: "read_model.apparatus",
        args: &["read_model", "apparatus"],
        owner: "read_model",
    },
    Scenario {
        id: "read_model.exercise",
        args: &["read_model", "exercise"],
        owner: "read_model",
    },
    // domain actors
    Scenario {
        id: "event.widget_created",
        args: &["event", "widget-created"],
        owner: "event",
    },
    Scenario {
        id: "aggregate.widget",
        args: &["aggregate", "widget"],
        owner: "aggregate",
    },
    // commands — the three operation templates
    Scenario {
        id: "command.create_widget",
        args: &["command", "create-widget"],
        owner: "command",
    },
    Scenario {
        id: "command.edit_widget",
        args: &["command", "edit-widget"],
        owner: "command",
    },
    Scenario {
        id: "command.archive_widget",
        args: &["command", "archive-widget"],
        owner: "command",
    },
    Scenario {
        id: "command_handler.create_widget",
        args: &["command_handler", "create-widget"],
        owner: "command_handler",
    },
    Scenario {
        id: "projector.widget_created",
        args: &["projector", "widget-created"],
        owner: "projector",
    },
    Scenario {
        id: "policy.create_widget",
        args: &["policy", "create-widget"],
        owner: "policy",
    },
    // queries — read vs collection
    Scenario {
        id: "query.read_widget",
        args: &["query", "read-widget"],
        owner: "query",
    },
    Scenario {
        id: "query.list_widgets",
        args: &["query", "list-widgets"],
        owner: "query",
    },
    Scenario {
        id: "internal_api.read_model_widget",
        args: &["internal_api", "read-model.widget"],
        owner: "internal_api",
    },
    Scenario {
        id: "public_api.create_widget",
        args: &["public_api", "create-widget"],
        owner: "public_api",
    },
    // web actors
    Scenario {
        id: "view.widget",
        args: &["view", "widget"],
        owner: "view",
    },
    Scenario {
        id: "schema.create_widget",
        args: &["schema", "create-widget"],
        owner: "schema",
    },
    Scenario {
        id: "controller.create_widget",
        args: &["controller", "create-widget"],
        owner: "controller",
    },
    Scenario {
        id: "controller.read_widget",
        args: &["controller", "read-widget"],
        owner: "controller",
    },
    Scenario {
        id: "bruno.read_widget",
        args: &["bruno", "read-widget"],
        owner: "bruno",
    },
    Scenario {
        id: "test_support.widget",
        args: &["test_support", "widget"],
        owner: "test_support",
    },
    // the whole constituent, generated in build order
    Scenario {
        id: "feature.widget",
        args: &["feature", "widget"],
        owner: "feature",
    },
];

/// Repo paths whose bytes depend on the driver, mapped per scenario to the
/// suffixed corpus entry that stores them. Everything shared is byte-equal
/// across drivers and needs no entry; the dedupe is the point — an entry
/// here is a documented statement that the suite run (or a delete command)
/// generates different code than the lone generator would.
const DRIVER_VARIANTS: &[(&str, &str, &str)] = &[
    // scenario id, repo-relative path, corpus path
    (
        "feature.widget",
        "widget/aggregate.ex",
        "aggregate/widget-feature.ex",
    ),
    (
        "feature.widget",
        "widget/operations/create_widget/handler.ex",
        "command_handler/create_widget-feature.ex",
    ),
    (
        "feature.widget",
        "widget/policy.ex",
        "policy/widget-feature.ex",
    ),
    (
        "feature.widget",
        "widget/projector.ex",
        "projector/widget-feature.ex",
    ),
    (
        "feature.widget",
        "widget/public_api.ex",
        "public_api/widget-feature.ex",
    ),
    (
        "feature.widget",
        "widget/widget_controller.ex",
        "controller/widget-feature.ex",
    ),
    (
        "feature.widget",
        "widget/events/widget_created_test.exs",
        "test/event/widget_created-feature.exs",
    ),
    (
        "feature.widget",
        "widget/widget_view_test.exs",
        "test/view/widget-feature.exs",
    ),
    (
        "feature.widget",
        "bruno/Catalog/Equipment/Widget/Read Widget.yml",
        "bruno/widget-read-feature.yml",
    ),
    (
        "command.archive_widget",
        "widget/internal.ex",
        "internal_api/widget-archive.ex",
    ),
];

/// The corpus entry for one created file: `category/<pattern-name>.<ext>`.
/// `None` means no rule covers the path — a loud test failure, so the table
/// below stays the complete record of where generated code lives.
fn pattern_name(rel: &str, scenario: &Scenario) -> Option<String> {
    for (scen, path_suffix, corpus) in DRIVER_VARIANTS {
        if *scen == scenario.id && rel.ends_with(path_suffix) {
            return Some((*corpus).to_string());
        }
    }

    let segs: Vec<&str> = rel.split('/').collect();
    let file = *segs.last()?;
    let parent = *segs.get(segs.len().checked_sub(2)?)?;
    let stem = file.split('.').next()?;

    // API collection folders, one yml per operation plus the folder itself
    if rel.starts_with("bruno/") {
        let object = kebab(parent);
        let stem = file.strip_suffix(".yml").unwrap_or(file);
        let stem = kebab(stem);
        let op = if stem == "folder" {
            "folder".to_string()
        } else {
            // "read widget" describes the widget object already in the name
            let plural = format!("{object}s");
            let words: Vec<&str> = stem
                .split('-')
                .filter(|w| *w != object && *w != plural)
                .collect();
            words.join("-")
        };
        return Some(format!("bruno/{object}-{op}.yml"));
    }

    // test support: the shared context module and the per-object fixtures
    if rel.starts_with("services/api/test/support/") {
        let name = if parent == "fixtures" {
            format!("fixtures-{stem}")
        } else {
            stem.to_string()
        };
        return Some(format!("test_support/{name}.ex"));
    }

    // companion tests of the domain side
    if rel.starts_with("services/api/test/sportipedia/") {
        let op = stem.strip_suffix("_test")?;
        return match parent {
            "events" => Some(format!("test/event/{op}.exs")),
            "operations" => Some(format!("test/{}/{}.exs", scenario.owner, op)),
            _ => None,
        };
    }

    // companion tests of the web side
    if rel.starts_with("services/api/test/sportipedia_web/") {
        return match parent {
            "schemas" => Some(format!("test/schema/{}.exs", stem.strip_suffix("_test")?)),
            "operations" => Some(format!(
                "test/controller/{}.exs",
                stem.strip_suffix("_endpoint_test")?
            )),
            _ => {
                let object = stem.strip_suffix("_view_test")?;
                Some(format!("test/view/{object}.exs"))
            }
        };
    }

    // the web library
    if rel.starts_with("services/api/lib/sportipedia_web/") {
        if parent == "schemas" {
            return Some(format!("schema/{stem}.ex"));
        }
        if let Some(object) = stem.strip_suffix("_controller") {
            return Some(format!("controller/{object}.ex"));
        }
        if let Some(object) = stem.strip_suffix("_view") {
            return Some(format!("view/{object}.ex"));
        }
        return None;
    }

    // the domain library
    rel.strip_prefix("services/api/lib/sportipedia/")?;
    Some(match file {
        "read_model.ex" => format!("read_model/{parent}.ex"),
        "aggregate.ex" => format!("aggregate/{parent}.ex"),
        "projector.ex" => format!("projector/{parent}.ex"),
        "policy.ex" => format!("policy/{parent}.ex"),
        "public_api.ex" => format!("public_api/{parent}.ex"),
        "internal.ex" => format!("internal_api/{parent}.ex"),
        "application.ex" => format!("application/{parent}.ex"),
        "command.ex" => format!("command/{parent}.ex"),
        "handler.ex" => format!("command_handler/{parent}.ex"),
        _ => match parent {
            "events" => format!("event/{stem}.ex"),
            "queries" => format!("query/{stem}.ex"),
            "validators" => format!("validator/{stem}.ex"),
            _ => return None,
        },
    })
}

fn kebab(text: &str) -> String {
    text.to_lowercase().replace(' ', "-")
}

#[test]
fn fresh_generation_matches_the_expected_files() {
    let update = update_requested();

    // run every scenario in parallel: fresh sandbox, one real run each
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
                    match pattern_name(&rel, scenario) {
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
        for (name, (content, _)) in &produced {
            let path = root.join(name);
            std::fs::create_dir_all(path.parent().unwrap()).unwrap();
            std::fs::write(&path, content).unwrap();
        }
        eprintln!(
            "wrote {} corpus files under {}",
            produced.len(),
            root.display()
        );
        return;
    }

    let on_disk = read_corpus(&expected_root());
    for (name, (content, ids)) in &produced {
        match on_disk.get(name) {
            None => problems.push(format!(
                "{name} was generated by [{ids}] but is not committed",
                ids = ids.join(", ")
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

/// One scenario over a fresh sandbox: the created files (path + bytes), after
/// every Elixir artifact has proven it parses.
fn run(scenario: &Scenario) -> Result<Vec<(String, String)>, String> {
    let root = sandbox(scenario.id);
    let before = output_files(&root);
    let (code, out) = sparch(&root, scenario.args);
    if code != 0 {
        cleanup(&root);
        return Err(format!("exit {code}:\n{out}"));
    }

    let files: Vec<(String, String)> = output_files(&root)
        .difference(&before)
        .map(|rel| (rel.clone(), common::read(&root, rel)))
        .collect();
    cleanup(&root);

    if files.is_empty() {
        return Err("created no files".to_string());
    }
    // the parse guard: nothing unparseable is ever trusted or written
    let unparseable: Vec<&str> = files
        .iter()
        .filter(|(rel, _)| rel.ends_with(".ex") || rel.ends_with(".exs"))
        .filter(|(_, text)| !ElixirFile::parse(text).parsed())
        .map(|(rel, _)| rel.as_str())
        .collect();
    if !unparseable.is_empty() {
        return Err(format!("generated unparseable files: {unparseable:?}"));
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

    fn scenario(id: &'static str, owner: &'static str) -> Scenario {
        Scenario {
            id,
            args: &[],
            owner,
        }
    }

    fn named(rel: &str, sc: &Scenario) -> String {
        pattern_name(rel, sc).unwrap_or_else(|| panic!("no pattern rule for {rel}"))
    }

    // one case per rule, on real paths from the fixture corpus
    #[test]
    fn every_created_path_maps_to_a_pattern_name() {
        let widget = scenario("read_model.widget", "read_model");
        assert_eq!(
            named(
                "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex",
                &widget
            ),
            "read_model/widget.ex"
        );
        assert_eq!(
            named(
                "services/api/lib/sportipedia/catalog/athlete/position/read_model.ex",
                &widget
            ),
            "read_model/position.ex"
        );
        assert_eq!(
            named(
                "services/api/lib/sportipedia/catalog/application.ex",
                &widget
            ),
            "application/catalog.ex"
        );

        let command = scenario("command.create_widget", "command");
        assert_eq!(
            named(
                "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/command.ex",
                &command
            ),
            "command/create_widget.ex"
        );
        assert_eq!(
            named(
                "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/handler.ex",
                &command
            ),
            "command_handler/create_widget.ex"
        );
        assert_eq!(
            named(
                "services/api/lib/sportipedia/catalog/equipment/widget/events/widget_created.ex",
                &command
            ),
            "event/widget_created.ex"
        );
        assert_eq!(
            named(
                "services/api/lib/sportipedia/catalog/equipment/widget/validators/unique_slug.ex",
                &command
            ),
            "validator/unique_slug.ex"
        );
        assert_eq!(
            named(
                "services/api/lib/sportipedia/catalog/equipment/widget/queries/widget_by_slug.ex",
                &command
            ),
            "query/widget_by_slug.ex"
        );
        assert_eq!(
            named(
                "services/api/lib/sportipedia/catalog/equipment/widget/internal.ex",
                &command
            ),
            "internal_api/widget.ex"
        );
        // a delete command drives a leaner internal API — its own entry
        let archive = scenario("command.archive_widget", "command");
        assert_eq!(
            named(
                "services/api/lib/sportipedia/catalog/equipment/widget/internal.ex",
                &archive
            ),
            "internal_api/widget-archive.ex"
        );

        let web = scenario("controller.create_widget", "controller");
        assert_eq!(
            named(
                "services/api/lib/sportipedia_web/catalog/equipment/widget/widget_controller.ex",
                &web
            ),
            "controller/widget.ex"
        );
        assert_eq!(
            named(
                "services/api/lib/sportipedia_web/catalog/equipment/widget/schemas/create_widget_request.ex",
                &web
            ),
            "schema/create_widget_request.ex"
        );
        assert_eq!(
            named(
                "services/api/lib/sportipedia_web/catalog/equipment/widget/widget_view.ex",
                &web
            ),
            "view/widget.ex"
        );

        let view = scenario("view.widget", "view");
        assert_eq!(
            named(
                "services/api/test/sportipedia_web/catalog/equipment/widget/widget_view_test.exs",
                &view
            ),
            "test/view/widget.exs"
        );
        assert_eq!(
            named(
                "services/api/test/sportipedia_web/catalog/equipment/widget/schemas/create_widget_request_test.exs",
                &view
            ),
            "test/schema/create_widget_request.exs"
        );
        assert_eq!(
            named(
                "services/api/test/sportipedia_web/catalog/equipment/widget/operations/create_widget_endpoint_test.exs",
                &view
            ),
            "test/controller/create_widget.exs"
        );

        // the shared operations test path is namespaced by its owner
        let policy = scenario("policy.create_widget", "policy");
        assert_eq!(
            named(
                "services/api/test/sportipedia/catalog/equipment/widget/operations/create_widget_test.exs",
                &policy
            ),
            "test/policy/create_widget.exs"
        );
        let event = scenario("event.widget_created", "event");
        assert_eq!(
            named(
                "services/api/test/sportipedia/catalog/equipment/widget/events/widget_created_test.exs",
                &event
            ),
            "test/event/widget_created.exs"
        );
        let support = scenario("test_support.widget", "test_support");
        assert_eq!(
            named(
                "services/api/test/support/catalog/equipment/equipment.ex",
                &support
            ),
            "test_support/equipment.ex"
        );
        assert_eq!(
            named(
                "services/api/test/support/catalog/equipment/fixtures/widgets.ex",
                &support
            ),
            "test_support/fixtures-widgets.ex"
        );

        let bruno = scenario("bruno.read_widget", "bruno");
        assert_eq!(
            named("bruno/Catalog/Equipment/Widget/Read Widget.yml", &bruno),
            "bruno/widget-read.yml"
        );
        assert_eq!(
            named("bruno/Catalog/Equipment/Widget/folder.yml", &bruno),
            "bruno/widget-folder.yml"
        );

        // the suite run's merged variants
        let feature = scenario("feature.widget", "feature");
        assert_eq!(
            named(
                "services/api/lib/sportipedia/catalog/equipment/widget/aggregate.ex",
                &feature
            ),
            "aggregate/widget-feature.ex"
        );
        assert_eq!(
            named(
                "services/api/lib/sportipedia_web/catalog/equipment/widget/widget_controller.ex",
                &feature
            ),
            "controller/widget-feature.ex"
        );
        assert_eq!(
            named(
                "services/api/test/sportipedia/catalog/equipment/widget/operations/create_widget_test.exs",
                &feature
            ),
            "test/feature/create_widget.exs"
        );
        // ...while its other citizens match the lone generators byte for byte
        assert_eq!(
            named(
                "services/api/lib/sportipedia/catalog/equipment/widget/aggregate.ex",
                &aggregate_of()
            ),
            "aggregate/widget.ex"
        );
    }

    fn aggregate_of() -> Scenario {
        scenario("aggregate.widget", "aggregate")
    }

    #[test]
    fn unknown_paths_have_no_rule() {
        let sc = scenario("read_model.widget", "read_model");
        assert!(
            pattern_name(
                "services/api/lib/sportipedia/catalog/equipment/widget/mystery.ex",
                &sc
            )
            .is_none()
        );
        assert!(pattern_name("docs/domain-model/catalog/domain.esdm.yaml", &sc).is_none());
    }

    #[test]
    fn corpus_paths_stay_flat_pattern_names() {
        // the shape rule: category dir, then one short file name, no repo mirror
        let sc = scenario("command.create_widget", "command");
        for rel in [
            "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/command.ex",
            "services/api/test/sportipedia/catalog/equipment/widget/events/widget_created_test.exs",
        ] {
            let name = named(rel, &sc);
            assert!(
                !name.starts_with("services/"),
                "{name} still mirrors the repo"
            );
            let depth = name.split('/').count();
            assert!(depth <= 3, "{name} nests deeper than category/dir + file");
        }
    }
}
