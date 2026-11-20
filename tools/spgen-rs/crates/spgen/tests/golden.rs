//! Acceptance for the crossover binary: the capability list, the arch
//! answers, the manual, validate, and the generate face — the sandbox
//! method the engine goldens use, one binary up.

use std::path::{Path, PathBuf};
use std::process::Command;

fn fixtures() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../fixtures")
        .canonicalize()
        .unwrap()
}

fn sandbox(tag: &str) -> PathBuf {
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let root = std::env::temp_dir().join(format!("spgen-tool-{tag}-{unique}"));
    copy_tree(&fixtures().join("repo"), &root);
    std::fs::create_dir_all(root.join("docs")).unwrap();
    copy_tree(
        &fixtures().join("domain-model"),
        &root.join("docs/domain-model"),
    );
    root
}

fn copy_tree(from: &Path, to: &Path) {
    std::fs::create_dir_all(to).unwrap();
    for entry in std::fs::read_dir(from).unwrap() {
        let entry = entry.unwrap();
        let target = to.join(entry.file_name());
        if entry.file_type().unwrap().is_dir() {
            copy_tree(&entry.path(), &target);
        } else {
            std::fs::copy(entry.path(), &target).unwrap();
        }
    }
}

fn spgen(args: &[&str]) -> (i32, String) {
    let binary = env!("CARGO_BIN_EXE_spgen");
    let output = Command::new(binary).args(args).output().expect("run spgen");
    let mut text = String::from_utf8_lossy(&output.stdout).to_string();
    text.push_str(&String::from_utf8_lossy(&output.stderr));
    (output.status.code().unwrap_or(-1), text)
}

fn first_pending_be() -> Option<&'static str> {
    spgen_elixir::blueprints::GENERATOR_ORDER
        .iter()
        .copied()
        .find(|g| spgen_elixir::blueprints::blueprint_for(g).is_none())
}

fn pending_operation_suite() -> Option<String> {
    let pending: Vec<&str> = spgen_elixir::suites::Suite::Operation
        .members()
        .iter()
        .copied()
        .filter(|g| spgen_elixir::blueprints::blueprint_for(g).is_none())
        .collect();
    if pending.is_empty() {
        None
    } else {
        Some(format!("pending: {}", pending.join(", ")))
    }
}

#[test]
fn capability_list_shows_bindings_not_binaries() {
    let (code, out) = spgen(&["generate"]);
    assert_eq!(code, 0);
    assert!(out.contains("mix sp.gen.read_model <element>"));
    assert!(!out.contains("[Elixir tool]"), "{out}");
    assert!(out.contains("pnpm spgen feature <read-model>"));
    assert!(out.contains("  test   storybook"), "{out}");
    assert!(out.contains("  domain schema"), "{out}");
    // the operation suite's pending list is computed from the registry, so
    // porting waves flip it without touching this test
    match pending_operation_suite() {
        Some(expected) => assert!(out.contains(&expected), "expected `{expected}`:\n{out}"),
        None => assert!(
            !out.contains("pending:"),
            "every suite is ready, the list must say nothing:\n{out}"
        ),
    }
    assert!(
        !out.contains("target/release/spgen"),
        "the list speaks binding calls, never internal binaries:\n{out}"
    );
}

#[test]
fn arch_answers_location_and_named_identifiers() {
    let root = sandbox("arch");
    let r = root.display().to_string();
    let (code, out) = spgen(&["arch", "location", "command", "create-widget", "--root", &r]);
    assert_eq!(code, 0, "{out}");
    assert!(out.contains("location:path: services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/command.ex"));
    assert!(
        out.contains("location:module: Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget")
    );

    let (code, out) = spgen(&["arch", "name", "command", "create-widget", "--root", &r]);
    assert_eq!(code, 0);
    assert!(out.contains("name:module:"));
    assert!(
        !out.contains("name:path"),
        "a name answer carries identifiers, not locations:\n{out}"
    );

    // test_support names the fixture functions the projection will define
    let (code, out) = spgen(&[
        "arch",
        "name",
        "test_support",
        "read-model.widget",
        "--root",
        &r,
    ]);
    assert_eq!(code, 0, "{out}");
    assert!(out.contains("name:fixture.equipment:widget:classic-widget: classic_widget"));
    assert!(out.contains("name:fixtures_module:"));

    // schema exists in both languages — ambiguity is stated, not guessed
    let (code, out) = spgen(&[
        "arch",
        "location",
        "schema",
        "read-model.widget",
        "--root",
        &r,
    ]);
    assert_eq!(code, 1);
    assert!(out.contains("exists in elixir and typescript"), "{out}");
    let (code, out) = spgen(&[
        "arch",
        "location",
        "schema",
        "read-model.widget",
        "--target",
        "typescript",
        "--root",
        &r,
    ]);
    assert_eq!(code, 0, "{out}");
    assert!(out.contains("apps/catalog/src/equipment/schemas/widget.ts"));

    cleanup(&root);
}

#[test]
fn validate_reads_the_model_contracts() {
    let root = sandbox("validate");
    let r = root.display().to_string();
    let (code, out) = spgen(&["validate", "--root", &r]);
    // the fixture corpus intentionally carries broken coach/team references
    assert_eq!(code, 1, "fixture model is not complete:\n{out}");
    assert!(out.contains("which no read model defines"));
    assert!(out.contains("spgen validate:"));
    // scoped: one element address works too — widget's own contracts are
    // clean, its broken coach/team references only appear in whole-model
    // mode (a subset cannot see the closed world, sp.check's rule)
    let (code, out) = spgen(&["validate", "read-model.widget", "--root", &r]);
    assert_eq!(code, 0, "widget's scoped contract is complete:\n{out}");
    assert!(out.contains("model complete"));
    cleanup(&root);
}

#[test]
fn man_pages_render_with_generated_headers() {
    let (code, out) = spgen(&["man", "read_model", "--plain"]);
    assert_eq!(code, 0, "{out}");
    for section in ["NAME", "SYNOPSIS", "OPTIONS", "DESCRIPTION"] {
        assert!(
            out.contains(section),
            "{section} missing from the page:\n{out}"
        );
    }
    assert!(
        out.contains("mix sp.gen.read_model [options] <READ-MODEL>"),
        "the synopsis is the binding call:\n{out}"
    );
    assert!(
        out.contains("The queryable projection of the events"),
        "the author's prose:\n{out}"
    );

    let (code, out) = spgen(&["man", "projector", "--roff"]);
    assert_eq!(code, 0, "{out}");
    assert!(
        out.starts_with(".TH \"SPGEN-PROJECTOR\""),
        "the roff source leads with the title line:\n{out}"
    );

    let (code, out) = spgen(&["man", "domain-object", "--plain"]);
    assert_eq!(code, 0, "{out}");
    assert!(out.contains("DESCRIPTION"), "{out}");
    assert!(
        out.contains("Generates the domain object interface and its fields type"),
        "the shortdoc is the description:\n{out}"
    );

    let (code, out) = spgen(&["man", "--plain"]);
    assert_eq!(code, 0, "{out}");
    assert!(out.contains("GENERATORS"), "{out}");
    assert!(
        out.contains("mix sp.gen.read_model <element> [options]"),
        "{out}"
    );
    assert!(out.contains("pnpm spgen storybook <read-model>"), "{out}");

    let (code, out) = spgen(&["man", "operation"]);
    assert_eq!(code, 1, "suites get no page:\n{out}");
    assert!(out.contains("no page for 'operation'"), "{out}");

    let (_code, out) = spgen(&["man", "--index"]);
    assert!(out.contains("backend/domain/read-model.md"));
    assert!(out.contains("spgen man read_model"));
}

#[test]
fn committed_roff_pages_are_what_the_generators_describe() {
    let fresh = std::env::temp_dir().join(format!(
        "spgen-man-write-{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let (code, out) = spgen(&["man", "--write", &fresh.display().to_string()]);
    assert_eq!(code, 0, "{out}");
    let committed = committed_roff();
    let mut fresh_names = list_roff(&fresh);
    let mut committed_names = list_roff(&committed);
    fresh_names.sort();
    committed_names.sort();
    assert_eq!(
        fresh_names, committed_names,
        "man/roff holds exactly these pages"
    );
    for name in &fresh_names {
        let built = std::fs::read(fresh.join(name)).unwrap();
        let checked = std::fs::read(committed.join(name)).unwrap();
        assert_eq!(
            built,
            checked,
            "man/roff/{} is stale; run `spgen man --write`",
            name.display()
        );
    }
    std::fs::remove_dir_all(&fresh).unwrap();
}

fn committed_roff() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../man/roff")
        .canonicalize()
        .unwrap()
}

fn list_roff(dir: &Path) -> Vec<PathBuf> {
    std::fs::read_dir(dir)
        .unwrap()
        .filter_map(Result::ok)
        .map(|entry| entry.file_name())
        .filter(|name| name.to_string_lossy().ends_with(".1"))
        .map(PathBuf::from)
        .collect()
}

#[test]
fn generate_runs_ported_engines_and_points_at_pending_ones() {
    let root = sandbox("generate");
    let r = root.display().to_string();
    let (code, out) = spgen(&["generate", "read_model", "widget", "--root", &r]);
    assert_eq!(code, 0, "the read_model engine generates: {out}");
    assert!(out.contains("Created"));
    let file = root.join("services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex");
    assert!(file.exists());
    let text = std::fs::read_to_string(&file).unwrap();
    assert!(text.contains("defmodule Sportipedia.Catalog.Equipment.Widget.WidgetReadModel do"));

    // a second run: nothing to do; the format pass is fine with that
    let (code, out) = spgen(&["generate", "read_model", "widget", "--root", &r]);
    assert_eq!(code, 0);
    assert!(out.contains("Ignored"), "{out}");

    // `command` joined the ported engines with wave 5, `command_handler`
    // with wave 6; both generate
    let (code, out) = spgen(&["generate", "command", "create-widget", "--root", &r]);
    assert_eq!(code, 0, "the command engine generates: {out}");
    assert!(out.contains("Created"), "{out}");
    let command_file = root.join(
        "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/command.ex",
    );
    assert!(command_file.exists());
    let (code, out) = spgen(&["generate", "command_handler", "create-widget", "--root", &r]);
    assert_eq!(code, 0, "the handler engine generates: {out}");
    assert!(out.contains("Created"), "{out}");
    let handler_file = root.join(
        "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/handler.ex",
    );
    assert!(handler_file.exists());

    // pending generators answer with the binding call, not an engine error
    if let Some(pending) = first_pending_be() {
        let (code, out) = spgen(&["generate", pending, "create-widget", "--root", &r]);
        assert_eq!(code, 1);
        assert!(
            out.contains(&format!("mix sp.gen.{pending}")),
            "the answer is the call to type:\n{out}"
        );
    }
    cleanup(&root);
}

#[test]
fn generate_slices_keep_the_membership_gate_through_the_new_face() {
    let root = sandbox("suites");
    let r = root.display().to_string();
    let element_for = |suite: &str| match suite {
        "operation" => "create-widget",
        "endpoint" => "read-widget",
        _ => "widget",
    };
    let mut refused = false;
    for suite in ["operation", "endpoint", "feature"] {
        let pending = spgen_elixir::suites::Suite::parse(suite)
            .expect("suite name")
            .members()
            .iter()
            .copied()
            .filter(|g| spgen_elixir::blueprints::blueprint_for(g).is_none())
            .count();
        if pending > 0 {
            refused = true;
            let (code, out) = spgen(&[
                "generate",
                suite,
                element_for(suite),
                "--target",
                "elixir",
                "--root",
                &r,
            ]);
            assert_eq!(
                code, 1,
                "{suite} must refuse with {pending} pending members"
            );
            assert!(
                out.contains(&format!("suite {suite} needs generators")),
                "{out}"
            );
        }
    }
    if !refused {
        // every suite is ported: the gate now means the suite runs
        let (code, out) = spgen(&["generate", "operation", "create-widget", "--root", &r]);
        assert_eq!(code, 0, "the operation suite runs:\n{out}");
    }
    cleanup(&root);
}

#[test]
fn usage_and_bogus_commands_use_clap_defaults() {
    let (code, out) = spgen(&[]);
    // clap's arg_required_else_help: usage on stderr, usage error code
    assert_eq!(code, 2);
    assert!(
        out.contains("spgen — the blueprint generators' own tool"),
        "{out}"
    );
    let (code, out) = spgen(&["nonsense"]);
    assert_eq!(code, 2);
    assert!(out.contains("unrecognized subcommand 'nonsense'"), "{out}");
    let (code, out) = spgen(&["--version"]);
    assert_eq!(code, 0);
    assert!(out.contains("spgen"), "{out}");
}

fn cleanup(root: &Path) {
    let _ = std::fs::remove_dir_all(root);
}
