//! Acceptance for the crossover binary: the capability list, the arch
//! answers, the manual, validate, and the generate face — the sandbox
//! method the engine acceptance tests use, one binary up.

use std::path::{Path, PathBuf};
use std::process::Command;

use sparch::plaintext;

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
    let root = std::env::temp_dir().join(format!("sparch-tool-{tag}-{unique}"));
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

fn sparch(args: &[&str]) -> (i32, String) {
    let binary = env!("CARGO_BIN_EXE_sparch");
    let output = Command::new(binary)
        .args(args)
        .output()
        .expect("run sparch");
    let mut text = String::from_utf8_lossy(&output.stdout).to_string();
    text.push_str(&String::from_utf8_lossy(&output.stderr));
    (output.status.code().unwrap_or(-1), text)
}

fn first_pending_be() -> Option<&'static str> {
    sparch_elixir::blueprints::GENERATOR_ORDER
        .iter()
        .copied()
        .find(|g| sparch_elixir::blueprints::blueprint_for(g).is_none())
}

fn pending_operation_suite() -> Option<String> {
    let pending: Vec<&str> = sparch_elixir::suites::Suite::Operation
        .members()
        .iter()
        .copied()
        .filter(|g| sparch_elixir::blueprints::blueprint_for(g).is_none())
        .collect();
    if pending.is_empty() {
        None
    } else {
        Some(format!("pending: {}", pending.join(", ")))
    }
}

#[test]
fn capability_list_shows_bindings_not_binaries() {
    let (code, out) = sparch(&["generate"]);
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
        !out.contains("target/release/sparch"),
        "the list speaks binding calls, never internal binaries:\n{out}"
    );
}

#[test]
fn arch_answers_location_and_named_identifiers() {
    let root = sandbox("arch");
    let r = root.display().to_string();
    let (code, out) = sparch(&["arch", "location", "command", "create-widget", "--root", &r]);
    assert_eq!(code, 0, "{out}");
    assert!(out.contains("location:path: services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/command.ex"));
    assert!(
        out.contains("location:module: Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget")
    );

    let (code, out) = sparch(&["arch", "name", "command", "create-widget", "--root", &r]);
    assert_eq!(code, 0);
    assert!(out.contains("name:module:"));
    assert!(
        !out.contains("name:path"),
        "a name answer carries identifiers, not locations:\n{out}"
    );

    // test_support names the fixture functions the projection will define
    let (code, out) = sparch(&[
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
    let (code, out) = sparch(&[
        "arch",
        "location",
        "schema",
        "read-model.widget",
        "--root",
        &r,
    ]);
    assert_eq!(code, 1);
    assert!(out.contains("exists in elixir and typescript"), "{out}");
    let (code, out) = sparch(&[
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
    let (code, out) = sparch(&["validate", "--root", &r]);
    // the fixture corpus intentionally carries broken coach/team references
    assert_eq!(code, 1, "fixture model is not complete:\n{out}");
    assert!(out.contains("which no read model defines"));
    assert!(out.contains("sparch validate:"));
    // scoped: one element address works too — widget's own contracts are
    // clean, its broken coach/team references only appear in whole-model
    // mode (a subset cannot see the closed world, sp.check's rule)
    let (code, out) = sparch(&["validate", "read-model.widget", "--root", &r]);
    assert_eq!(code, 0, "widget's scoped contract is complete:\n{out}");
    assert!(out.contains("model complete"));
    cleanup(&root);
}

#[test]
fn man_pages_put_the_content_into_the_roff() {
    // The roff is what sparch writes, so the content is compared there. What a
    // formatter does with it afterwards is not sparch's answer, and groff and
    // mandoc disagree about spacing, hyphenation, color and even input encoding.
    // The text comes out of this crate's own rendering of that roff.
    let (code, roff) = sparch(&["man", "read_model", "--roff"]);
    assert_eq!(code, 0, "{roff}");
    let page = plaintext::render(&roff);
    for want in [
        "NAME\n    sparch-read_model - Generates the shared read model with its changesets",
        "SYNOPSIS\n    mix sp.gen.read_model [options] <READ-MODEL>",
        "DESCRIPTION\n    The queryable projection of the events. Typed Ecto schema plus the changesets the projections need.",
        // The blueprint prose carries an em dash. It reaches the page as a plain
        // dash, because no renderer is trusted to decode it the same way twice.
        "casting the fields they need - with a unique_constraint",
        "Left to you\n    - The table: mix ecto.gen.migration, including the unique index a unique_constraint needs",
        "OPTIONS\n    --subdomain <SUBDOMAIN>",
        "    --model <MODEL>\n    model root, default docs/domain-model (relative to --root)",
        "    <READ-MODEL>\n    the element: esdm: reference, *.esdm.yaml, kind.name, or bare name",
        "SEE ALSO\n    sparch(1)\n    suites: operation, feature",
    ] {
        assert!(page.contains(want), "missing from the page: {want}\n{page}");
    }
    for name in ["read_model", "projector", "domain-object", "storybook"] {
        let (code, roff) = sparch(&["man", name, "--roff"]);
        assert_eq!(code, 0, "{roff}");
        assert!(
            roff.is_ascii(),
            "{name}: a typographic character reached the roff, where a formatter \
             that decodes its input as latin1 turns it into mojibake\n{roff}"
        );
    }
    let (code, index) = sparch(&["man", "--roff"]);
    assert_eq!(code, 0, "{index}");
    assert!(
        index.is_ascii(),
        "the index carries every generator's shortdoc, and must stay ASCII:\n{index}"
    );
}

#[test]
fn man_pages_render_with_generated_headers() {
    // The `--plain` face is that same rendering, so the binary and the library
    // must agree, and nothing a formatter leaks may appear in either.
    let (code, roff) = sparch(&["man", "read_model", "--roff"]);
    assert_eq!(code, 0, "{roff}");
    let (code, out) = sparch(&["man", "read_model", "--plain"]);
    assert_eq!(code, 0, "{out}");
    assert_eq!(
        out,
        plaintext::render(&roff),
        "the binary does not print this crate's own rendering"
    );
    for section in ["NAME", "SYNOPSIS", "OPTIONS", "DESCRIPTION"] {
        assert!(
            out.contains(section),
            "{section} missing from the page:\n{out}"
        );
    }

    // Three artifacts the Linux formatter used to leak into the text: escape
    // sequences meant for a terminal, a mis-decoded UTF-8 dash, and roff itself.
    assert!(!out.contains('\u{1b}'), "the page carries escapes:\n{out}");
    assert!(!out.contains("â"), "the page carries mojibake:\n{out}");
    assert!(!out.contains(".SH"), "the page carries roff noise:\n{out}");

    let (code, out) = sparch(&["man", "projector", "--roff"]);
    assert_eq!(code, 0, "{out}");
    assert!(
        out.starts_with(".TH \"SPARCH-PROJECTOR\""),
        "the roff source leads with the title line:\n{out}"
    );

    let (code, out) = sparch(&["man", "domain-object", "--plain"]);
    assert_eq!(code, 0, "{out}");
    assert!(out.contains("DESCRIPTION"), "{out}");
    assert!(
        out.contains("Generates the domain object interface and its fields type"),
        "the shortdoc is the description:\n{out}"
    );

    let (code, out) = sparch(&["man", "--plain"]);
    assert_eq!(code, 0, "{out}");
    assert!(out.contains("GENERATORS"), "{out}");
    assert!(
        out.contains("mix sp.gen.read_model <element> [options]"),
        "{out}"
    );
    assert!(out.contains("pnpm spgen storybook <read-model>"), "{out}");

    let (code, out) = sparch(&["man", "operation"]);
    assert_eq!(code, 1, "suites get no page:\n{out}");
    assert!(out.contains("no page for 'operation'"), "{out}");

    let (_code, out) = sparch(&["man", "--index"]);
    assert!(out.contains("backend/domain/read-model.md"));
    assert!(out.contains("sparch man read_model"));
}

#[test]
fn generate_runs_ported_engines_and_points_at_pending_ones() {
    let root = sandbox("generate");
    let r = root.display().to_string();
    let (code, out) = sparch(&["generate", "read_model", "widget", "--root", &r]);
    assert_eq!(code, 0, "the read_model engine generates: {out}");
    assert!(out.contains("Created"));
    let file = root.join("services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex");
    assert!(file.exists());
    let text = std::fs::read_to_string(&file).unwrap();
    assert!(text.contains("defmodule Sportipedia.Catalog.Equipment.Widget.WidgetReadModel do"));

    // a second run: nothing to do; the format pass is fine with that
    let (code, out) = sparch(&["generate", "read_model", "widget", "--root", &r]);
    assert_eq!(code, 0);
    assert!(out.contains("Ignored"), "{out}");

    // `command` joined the ported engines with wave 5, `command_handler`
    // with wave 6; both generate
    let (code, out) = sparch(&["generate", "command", "create-widget", "--root", &r]);
    assert_eq!(code, 0, "the command engine generates: {out}");
    assert!(out.contains("Created"), "{out}");
    let command_file = root.join(
        "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/command.ex",
    );
    assert!(command_file.exists());
    let (code, out) = sparch(&["generate", "command_handler", "create-widget", "--root", &r]);
    assert_eq!(code, 0, "the handler engine generates: {out}");
    assert!(out.contains("Created"), "{out}");
    let handler_file = root.join(
        "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/handler.ex",
    );
    assert!(handler_file.exists());

    // pending generators answer with the binding call, not an engine error
    if let Some(pending) = first_pending_be() {
        let (code, out) = sparch(&["generate", pending, "create-widget", "--root", &r]);
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
        let pending = sparch_elixir::suites::Suite::parse(suite)
            .expect("suite name")
            .members()
            .iter()
            .copied()
            .filter(|g| sparch_elixir::blueprints::blueprint_for(g).is_none())
            .count();
        if pending > 0 {
            refused = true;
            let (code, out) = sparch(&[
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
        let (code, out) = sparch(&["generate", "operation", "create-widget", "--root", &r]);
        assert_eq!(code, 0, "the operation suite runs:\n{out}");
    }
    cleanup(&root);
}

#[test]
fn usage_and_bogus_commands_use_clap_defaults() {
    let (code, out) = sparch(&[]);
    // clap's arg_required_else_help: usage on stderr, usage error code
    assert_eq!(code, 2);
    assert!(
        out.contains("sparch — the blueprint generators' own tool"),
        "{out}"
    );
    let (code, out) = sparch(&["nonsense"]);
    assert_eq!(code, 2);
    assert!(out.contains("unrecognized subcommand 'nonsense'"), "{out}");
    let (code, out) = sparch(&["--version"]);
    assert_eq!(code, 0);
    assert!(out.contains("sparch"), "{out}");
}

fn cleanup(root: &Path) {
    let _ = std::fs::remove_dir_all(root);
}
