//! End-to-end acceptance of the BE binary, the way `sparch-typescript`'s acceptance
//! drives the FE binary: a sandbox repository from the shared fixture
//! corpus, the real compiled CLI, and the four Elixir-tool acceptance
//! criteria re-expressed in Rust — pickup, resurrection, black-box,
//! fixture-driven.

use std::path::{Path, PathBuf};
use std::process::Command;

use sparch_elixir::{
    blueprints::{GENERATOR_ORDER, blueprint_for},
    suites::Suite,
};

fn pending_join(members: &[&'static str]) -> Option<String> {
    let p: Vec<&str> = members
        .iter()
        .copied()
        .filter(|g| blueprint_for(g).is_none())
        .collect();
    (!p.is_empty()).then(|| p.join(", "))
}

fn first_unported() -> Option<&'static str> {
    GENERATOR_ORDER
        .iter()
        .copied()
        .find(|g| blueprint_for(g).is_none())
}

fn fixtures() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../fixtures")
        .canonicalize()
        .expect("shared fixture corpus")
}

/// A fresh copy of the fixture repository: hosts in place, model mounted
/// at `docs/domain-model`, no generated citizen yet.
fn sandbox(tag: &str) -> PathBuf {
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let root = std::env::temp_dir().join(format!("sparch-elixir-{tag}-{unique}"));
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

fn sparch(root: &Path, args: &[&str]) -> (i32, String) {
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");
    let output = Command::new(binary)
        .args(args)
        .arg("--root")
        .arg(root)
        .output()
        .expect("run sparch-elixir");
    let mut text = String::from_utf8_lossy(&output.stdout).to_string();
    text.push_str(&String::from_utf8_lossy(&output.stderr));
    (output.status.code().unwrap_or(-1), text)
}

const READ_MODEL: &str = "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex";

#[test]
fn fresh_tree_creates_the_read_model() {
    let root = sandbox("create");
    let (code, out) = sparch(&root, &["read_model", "widget"]);
    assert_eq!(code, 0, "run failed: {out}");
    assert!(out.contains("Created"), "expected a Created group:\n{out}");
    let file = root.join(READ_MODEL);
    let text = std::fs::read_to_string(&file).expect("the read model was created");

    // everything the blueprint renders, in the model's own words
    assert!(text.contains("defmodule Sportipedia.Catalog.Equipment.Widget.WidgetReadModel do"));
    assert!(text.contains("use TypedEctoSchema"));
    assert!(text.contains("import Ecto.Changeset"));
    assert!(text.contains("@primary_key {:id, :binary_id, autogenerate: false}"));
    assert!(text.contains("@schema_prefix \"catalog\""));
    assert!(text.contains("typed_schema \"widget\" do"));
    assert!(text.contains("field :title, :string"));
    assert!(text.contains("field :slug, :string"));
    assert!(text.contains("field :archivedAt, :utc_datetime_usec"));
    assert!(text.contains("field :coachId, :binary_id"));
    assert!(text.contains("timestamps()"));
    assert!(text.contains("def insert_changeset(read_model, attrs) do"));
    assert!(text.contains("def update_changeset(read_model, attrs) do"));
    // unique-slug is an aggregate invariant — the constraint follows it
    assert!(text.contains("unique_constraint(:slug, name: :widget_slug_index)"));
    // the file parses — the splice path never breaks the tree it edits
    assert!(sparch_elixir::elixir::ElixirFile::parse(&text).parsed());

    cleanup(&root);
}

#[test]
fn pickup_reruns_change_nothing() {
    let root = sandbox("pickup");
    let (code, _) = sparch(&root, &["read_model", "widget"]);
    assert_eq!(code, 0);
    let before = std::fs::read(root.join(READ_MODEL)).unwrap();

    let (code, out) = sparch(&root, &["read_model", "widget"]);
    assert_eq!(code, 0, "rerun failed: {out}");
    assert!(out.contains("Ignored"), "second run ignores:\n{out}");
    assert!(
        !out.contains("Created"),
        "second run creates nothing:\n{out}"
    );
    assert_eq!(before, std::fs::read(root.join(READ_MODEL)).unwrap());

    // and `--dry-run` says so in future tense over nothing to do
    let (code, out) = sparch(&root, &["read_model", "widget", "--dry-run"]);
    assert_eq!(code, 0);
    assert!(
        !out.contains("Would create") && !out.contains("Would update"),
        "--dry-run after the chain is a no-op:\n{out}"
    );
    cleanup(&root);
}

#[test]
fn resurrection_backfills_a_deleted_unit() {
    let root = sandbox("resurrect");
    sparch(&root, &["read_model", "widget"]);
    let file = root.join(READ_MODEL);
    let text = std::fs::read_to_string(&file).unwrap();
    // a human deletes one field line (the Elixir rule: any full re-check
    // must resurrect exactly the missing unit)
    let deleted: String = text
        .lines()
        .filter(|line| !line.trim().starts_with("field :label"))
        .collect::<Vec<_>>()
        .join("\n");
    std::fs::write(&file, format!("{deleted}\n")).unwrap();

    let (code, out) = sparch(&root, &["read_model", "widget"]);
    assert_eq!(code, 0, "run failed: {out}");
    assert!(
        out.contains("Updated"),
        "the deleted line is restored:\n{out}"
    );
    let after = std::fs::read_to_string(&file).unwrap();
    assert!(after.contains("field :label, :string"));
    // the human bytes around it are untouched — only the missing unit was spliced in
    assert!(after.contains("field :title, :string"));
    assert!(after.contains("unique_constraint(:slug, name: :widget_slug_index)"));
    cleanup(&root);
}

#[test]
fn dry_run_writes_nothing() {
    let root = sandbox("dry-run");
    let (code, out) = sparch(&root, &["read_model", "widget", "--dry-run"]);
    assert_eq!(code, 0, "dry-run failed: {out}");
    assert!(
        out.contains("Would create"),
        "empty tree reports creation:\n{out}"
    );
    assert!(!root.join(READ_MODEL).exists(), "--dry-run writes nothing");
    cleanup(&root);
}

#[test]
fn unported_generators_point_at_the_live_tool() {
    let root = sandbox("unported");
    let Some(pending) = first_unported() else {
        cleanup(&root);
        return;
    };
    let (code, out) = sparch(&root, &[pending, "widget"]);
    assert_eq!(code, 1, "unported generator must fail loudly");
    assert!(
        out.contains("not ported to sparch-elixir yet"),
        "the message states the port status: {out}"
    );
    cleanup(&root);
}

#[test]
fn suites_refuse_until_every_member_is_ported() {
    let root = sandbox("suite-refusal");
    if let Some(pending) = pending_join(Suite::Operation.members()) {
        let (code, out) = sparch(&root, &["operation", "create-widget"]);
        assert_eq!(code, 1, "a half-suite must refuse, not under-generate");
        assert!(out.contains("not ported to sparch-elixir yet"), "{out}");
        assert!(
            out.contains(&pending),
            "the refusal names the members: {out}"
        );
    }

    if let Some(pending) = pending_join(Suite::Endpoint.members()) {
        let (code, out) = sparch(&root, &["endpoint", "read-widget"]);
        assert_eq!(code, 1);
        assert!(
            out.contains(&pending),
            "the endpoint refusal lists its own members in suite order: {out}"
        );
    }

    if let Some(pending) = pending_join(Suite::Feature.members()) {
        let (code, out) = sparch(&root, &["feature", "widget"]);
        assert_eq!(code, 1);
        assert!(
            out.contains("suite feature needs generators"),
            "feature refuses too ({pending}): {out}"
        );
    }
    cleanup(&root);
}

#[test]
fn suites_take_no_template() {
    let root = sandbox("suite-template");
    let (code, out) = sparch(
        &root,
        &["operation", "create-widget", "--template", "create"],
    );
    assert_eq!(code, 1);
    assert!(
        out.contains("takes no --template"),
        "the operation comes from the model, not the suite caller: {out}"
    );
    cleanup(&root);
}

#[test]
fn the_listing_states_the_tiers_and_suite_status() {
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");
    let output = Command::new(binary).output().expect("run sparch-elixir");
    let out = String::from_utf8_lossy(&output.stdout).to_string();
    assert_eq!(output.status.code(), Some(0));
    assert!(
        out.contains("blueprints render units; generators run blueprints; suites run generators"),
        "the tier sentence leads the listing:\n{out}"
    );
    assert!(
        out.contains("mix sp.gen.operation"),
        "suites are listed:\n{out}"
    );
    assert!(
        out.contains("mix sp.gen.feature  — ready"),
        "suites carry status:\n{out}"
    );
}

#[test]
fn resolution_and_kind_guards_behave_like_the_be_tool() {
    let root = sandbox("resolve");
    // the read model and the aggregate share the name `widget`; kinds
    // narrow, a `kind.name` address disambiguates
    let (code, out) = sparch(&root, &["read_model", "read-model.widget"]);
    assert_eq!(code, 0, "kind.name address resolves: {out}");
    let (code, out) = sparch(&root, &["read_model", "aggregate.widget"]);
    assert_eq!(code, 1, "wrong kind is refused");
    assert!(
        out.contains("generates from"),
        "kind error names the contract: {out}"
    );
    let (code, out) = sparch(&root, &["read_model", "widget", "--template", "create"]);
    assert_eq!(code, 1, "a fixed blueprint takes no template");
    assert!(out.contains("is fixed"), "the error states why: {out}");
    cleanup(&root);
}

#[test]
fn dry_run_can_list_the_units_it_would_place() {
    let root = sandbox("verbose");
    // a hand-trimmed field line: the dry run sees it, --verbose names it
    let (_, _) = sparch(&root, &["read_model", "widget"]);
    let file = root.join(READ_MODEL);
    let text = std::fs::read_to_string(&file).unwrap();
    let trimmed: String = text
        .lines()
        .filter(|line| !line.trim().starts_with("field :description"))
        .collect::<Vec<_>>()
        .join("\n");
    std::fs::write(&file, format!("{trimmed}\n")).unwrap();

    let (code, out) = sparch(&root, &["read_model", "widget", "--dry-run", "--verbose"]);
    assert_eq!(code, 0, "{out}");
    assert!(out.contains("Would update"), "{out}");
    assert!(
        out.contains("+ field description"),
        "--verbose names the unit that would land:\n{out}"
    );

    // the same line without --verbose stays exactly the old report shape
    let (_, plain) = sparch(&root, &["read_model", "widget", "--dry-run"]);
    assert!(
        !plain.contains("+ field description"),
        "default is terse:\n{plain}"
    );

    // --verbose outside a dry run changes nothing (it cannot — writes are writes)
    let (code, out) = sparch(&root, &["read_model", "widget", "--verbose"]);
    assert_eq!(code, 0, "{out}");
    assert!(
        out.contains("Updated"),
        "a real run reports real states:\n{out}"
    );
    assert!(!out.contains("+ field description"));

    cleanup(&root);
}

#[test]
fn the_old_check_flag_is_gone() {
    let root = sandbox("old-flag");
    let (code, out) = sparch(&root, &["read_model", "widget", "--check"]);
    // clap's own verdict on a removed flag: usage error, its exit code 2
    assert_eq!(code, 2, "--check no longer exists");
    assert!(out.contains("unexpected argument '--check'"), "{out}");
    cleanup(&root);
}

fn cleanup(root: &Path) {
    let _ = std::fs::remove_dir_all(root);
}
