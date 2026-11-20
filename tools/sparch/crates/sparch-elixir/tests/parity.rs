//! Parity gate against the Elixir oracle, opt-in: `SPARCH_ORACLE` points at
//! a built `tools/spgen` escript and `elixir` must be on PATH.
//!
//! The claim under test is the write-path verdict: splicing text into the
//! human bytes and formatting once with the project's formatter must land
//! on the same file the AST-merge-and-reprint tool lands on. The oracle
//! formats inside its own run; the new pipeline gets the identical
//! `Code.format_string!` pass through a throwaway script.

use std::path::{Path, PathBuf};
use std::process::Command;

fn oracle() -> Option<PathBuf> {
    let raw = std::env::var("SPARCH_ORACLE").ok()?;
    let path = PathBuf::from(raw);
    path.is_file().then_some(path)
}

fn sandbox(tag: &str) -> PathBuf {
    use std::sync::atomic::{AtomicUsize, Ordering};
    // tests run in parallel on one clock; the nanosecond alone can collide
    // between two threads and hand them the same tree (one test's cleanup
    // would then delete the other's sandbox) — a sequence number keeps the
    // names apart.
    static SEQ: AtomicUsize = AtomicUsize::new(0);
    let fixtures = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../fixtures")
        .canonicalize()
        .unwrap();
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let seq = SEQ.fetch_add(1, Ordering::Relaxed);
    let root = std::env::temp_dir().join(format!("sparch-parity-{tag}-{unique}-{seq}"));
    copy_tree(&fixtures.join("repo"), &root);
    std::fs::create_dir_all(root.join("docs")).unwrap();
    copy_tree(
        &fixtures.join("domain-model"),
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

/// The Elixir tool's formatter pass, applied to one file in place: the
/// same `Code.format_string!` and the same evaluated `.formatter.exs`
/// options the oracle applies through `SpGen.Formatter`.
fn format_with_elixir(api_dir: &Path, file: &Path) {
    let script = r#"
{:ok, opts_src} = File.read(".formatter.exs")
{opts_term, _} = Code.eval_string(opts_src)
opts =
  opts_term
  |> Enum.flat_map(fn
    {:locals_without_parens, list} -> [{:locals_without_parens, list}]
    _ -> []
  end)
[path] = System.argv()
formatted = path |> File.read!() |> Code.format_string!(opts)
File.write!(path, [formatted, "\n"])
"#;
    let status = Command::new("elixir")
        .arg("-e")
        .arg(script)
        .arg(file)
        .current_dir(api_dir)
        .status()
        .expect("run elixir formatter");
    assert!(status.success(), "elixir formatter failed");
}

const READ_MODEL: &str = "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex";

/// Run a generator binary against a sandbox root, failing on non-zero exit.
fn run_gen<A: AsRef<std::ffi::OsStr>>(binary: A, root: &std::path::Path, args: &[&str]) {
    let status = Command::new(binary)
        .args(args)
        .arg("--root")
        .arg(root)
        .status()
        .expect("run generator");
    assert!(status.success(), "run failed: {args:?}");
}

/// The same for a run whose report text the caller reads.
fn run_gen_out<A: AsRef<std::ffi::OsStr>>(
    binary: A,
    root: &std::path::Path,
    args: &[&str],
) -> (bool, String) {
    let output = Command::new(binary)
        .args(args)
        .arg("--root")
        .arg(root)
        .output()
        .expect("run generator");
    let mut text = String::from_utf8_lossy(&output.stdout).to_string();
    text.push_str(&String::from_utf8_lossy(&output.stderr));
    (output.status.success(), text)
}

#[test]
fn read_model_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };

    // the oracle: formats inside its own run
    let old = sandbox("oracle");
    let status = Command::new(&oracle)
        .args(["read_model", "widget", "--root"])
        .arg(&old)
        .status()
        .expect("run oracle escript");
    assert!(status.success(), "oracle run failed");

    // the port: splice now, format once — exactly what the mix binding does
    let new = sandbox("port");
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");
    let status = Command::new(binary)
        .args(["read_model", "widget", "--root"])
        .arg(&new)
        .status()
        .expect("run sparch-elixir");
    assert!(status.success(), "port run failed");
    let new_file = new.join(READ_MODEL);
    format_with_elixir(&new.join("services/api"), &new_file);

    let oracle_text = std::fs::read_to_string(old.join(READ_MODEL)).unwrap();
    let port_text = std::fs::read_to_string(&new_file).unwrap();
    assert_eq!(
        port_text, oracle_text,
        "the splice+format path must land where the reprint+format path lands"
    );

    let _ = std::fs::remove_dir_all(&old);
    let _ = std::fs::remove_dir_all(&new);
}

/// The event's module file and test file — every path the `event`
/// generator writes for one element.
fn event_paths(event_snake: &str) -> [String; 2] {
    [
        format!("services/api/lib/sportipedia/catalog/equipment/widget/events/{event_snake}.ex"),
        format!(
            "services/api/test/sportipedia/catalog/equipment/widget/events/{event_snake}_test.exs"
        ),
    ]
}

#[test]
fn event_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");

    // Three shapes, run in the same order on both sides: the derived
    // `create` fact, the derived `update` fact with its `get_changes/1`
    // (the read model's projection declares it), and a forced
    // `--template update` over a declared `delete` fact.
    let cases: [(&[&str], &str); 3] = [
        (&["event", "widget-created"], "widget_created"),
        (&["event", "widget-edited"], "widget_edited"),
        (
            &["event", "widget-archived", "--template", "update"],
            "widget_archived",
        ),
    ];

    // the oracle: formats inside its own run
    let old = sandbox("oracle");
    for (args, _snake) in cases {
        run_gen(&oracle, &old, args);
    }

    // the port: splice now, format once — exactly what the mix binding does
    let new = sandbox("port");
    for (args, _snake) in cases {
        run_gen(binary, &new, args);
    }

    let mut written: Vec<String> = Vec::new();
    for (_args, snake) in cases {
        for path in event_paths(snake) {
            format_with_elixir(&new.join("services/api"), &new.join(&path));
            written.push(path);
        }
    }

    // every file the generator wrote matches, byte for byte
    for path in &written {
        let oracle_text = std::fs::read_to_string(old.join(path)).unwrap();
        let port_text = std::fs::read_to_string(new.join(path)).unwrap();
        assert_eq!(port_text, oracle_text, "event file differs: {path}");
    }

    // pickup: running the port over the oracle-produced tree changes nothing
    let before: Vec<Vec<u8>> = written
        .iter()
        .map(|path| std::fs::read(old.join(path)).unwrap())
        .collect();
    for (args, _snake) in cases {
        run_gen(binary, &old, args);
    }
    for (path, bytes) in written.iter().zip(&before) {
        assert_eq!(
            &std::fs::read(old.join(path)).unwrap(),
            bytes,
            "the port rewrote a file the oracle produced: {path}"
        );
    }

    let _ = std::fs::remove_dir_all(&old);
    let _ = std::fs::remove_dir_all(&new);
}

/// Every file the `aggregate` generator writes for the widget constituent:
/// the aggregate module itself plus the `describe "Aggregate"` block it
/// contributes to each event's test file (its companion blueprint's output).
fn aggregate_paths() -> Vec<String> {
    let mut paths =
        vec!["services/api/lib/sportipedia/catalog/equipment/widget/aggregate.ex".to_string()];
    paths.extend(
        [
            "widget_archived",
            "widget_created",
            "widget_edited",
            "widget_noted",
            "widget_relabelled",
            "widget_rename_logged",
        ]
        .iter()
        .map(|snake| {
            format!(
                "services/api/test/sportipedia/catalog/equipment/widget/events/{snake}_test.exs"
            )
        }),
    );
    paths
}

#[test]
fn aggregate_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");

    // The events are generated first, in the known-good build order: the
    // aggregate's aliases and `apply/2` clauses are gated on the event
    // modules, and this is what lets them land instead of defer. All six
    // widget events are needed — the aggregate reads its fold from what
    // the read model *declares* per event, and the fixture declares every
    // effect shape: create, update (twice), delete, and the declared none
    // (twice). The aggregate is fixed-shape, so there is no `--template`
    // variant to carry; the second run drives the same aggregate from an
    // event element, a source the oracle's `source_kinds` accepts.
    let sequence: Vec<Vec<&str>> = vec![
        vec!["event", "widget-created"],
        vec!["event", "widget-edited"],
        vec!["event", "widget-archived"],
        vec!["event", "widget-relabelled"],
        vec!["event", "widget-noted"],
        vec!["event", "widget-rename-logged"],
        vec!["aggregate", "widget"],
        vec!["aggregate", "widget-noted"],
    ];

    // the oracle: formats inside its own run
    let old = sandbox("oracle");
    for args in &sequence {
        run_gen(&oracle, &old, args);
    }

    // the port: splice now, format once — exactly what the mix binding does
    let new = sandbox("port");
    for args in &sequence {
        run_gen(binary, &new, args);
    }

    let written = aggregate_paths();
    for path in &written {
        format_with_elixir(&new.join("services/api"), &new.join(path));
    }

    // every file the generator wrote matches, byte for byte
    for path in &written {
        let oracle_text = std::fs::read_to_string(old.join(path)).unwrap();
        let port_text = std::fs::read_to_string(new.join(path)).unwrap();
        assert_eq!(port_text, oracle_text, "aggregate file differs: {path}");
    }

    // the fold clauses landed for every declared effect
    let aggregate = std::fs::read_to_string(new.join(&written[0])).unwrap();
    for event in [
        "WidgetCreated",
        "WidgetEdited",
        "WidgetArchived",
        "WidgetRelabelled",
        "WidgetNoted",
        "WidgetRenameLogged",
    ] {
        assert!(
            aggregate.contains(&format!("%{event}")),
            "no apply clause for {event}:\n{aggregate}"
        );
    }

    // pickup: running the port over the oracle-produced tree changes nothing
    let before: Vec<Vec<u8>> = written
        .iter()
        .map(|path| std::fs::read(old.join(path)).unwrap())
        .collect();
    for args in &sequence[6..] {
        run_gen(binary, &old, args);
    }
    for (path, bytes) in written.iter().zip(&before) {
        assert_eq!(
            &std::fs::read(old.join(path)).unwrap(),
            bytes,
            "the port rewrote a file the oracle produced: {path}"
        );
    }

    let _ = std::fs::remove_dir_all(&old);
    let _ = std::fs::remove_dir_all(&new);
}

/// The widget query's own module file.
fn query_module(snake: &str) -> String {
    format!("services/api/lib/sportipedia/catalog/equipment/widget/queries/{snake}.ex")
}

/// The operation test file a widget query's describe lands in.
fn operation_test(snake: &str) -> String {
    format!("services/api/test/sportipedia/catalog/equipment/widget/operations/{snake}_test.exs")
}

/// Every file the `query` generator writes for the widget citizen: each
/// query's own module, the operation test file its companion blueprint
/// contributes to, and — for the collection query, whose body delegates —
/// the read model it names (planned as the blueprint's dependency).
fn query_paths() -> Vec<String> {
    let mut paths = Vec::new();
    for snake in ["read_widget", "list_widgets"] {
        paths.push(query_module(snake));
        paths.push(operation_test(snake));
    }
    paths.push(READ_MODEL.to_string());
    paths
}

/// The `new/1` body a run before this blueprint knew the shape left standing:
/// a `TODO:` marker over a query the model now declares a collection.
const STANDING_MARKER: &str = r#"defmodule Sportipedia.Catalog.Equipment.Widget.Queries.ListWidgets do
  @moduledoc """
  List all widgets with filtering, sorting, and pagination
  """
  @doc """
  Creates a new query to fetch widgets.
  """
  @spec new(map()) :: Ecto.Query.t()
  def new(_params) do
    # TODO: construct and return the query from the read model
    raise "TODO: implement list-widgets query (see the feature spec)"
  end
end
"#;

#[test]
fn query_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");

    // Both shapes the corpus declares for the widget citizen, run in the same
    // order on both sides: `read-widget`, which declares no operation and
    // whose `result.type: object` derives the marker body, and
    // `list-widgets`, which declares `spgen.operation: collection` and gets
    // the delegating body with its two aliases and its read model. The
    // generator is fixed-shape (the oracle declares no `operations/0`), so no
    // run carries `--template`: the refusal is asserted at the end.
    let sequence: Vec<Vec<&str>> =
        vec![vec!["query", "read-widget"], vec!["query", "list-widgets"]];

    // the oracle: formats inside its own run
    let old = sandbox("oracle");
    for args in &sequence {
        run_gen(&oracle, &old, args);
    }

    // the port: splice now, format once — exactly what the mix binding does
    let new = sandbox("port");
    for args in &sequence {
        run_gen(binary, &new, args);
    }

    let written = query_paths();
    for path in &written {
        format_with_elixir(&new.join("services/api"), &new.join(path));
    }

    // every file the generator wrote matches, byte for byte
    for path in &written {
        let oracle_text = std::fs::read_to_string(old.join(path)).unwrap();
        let port_text = std::fs::read_to_string(new.join(path)).unwrap();
        assert_eq!(port_text, oracle_text, "query file differs: {path}");
    }

    // the two shapes really are the two shapes
    let read = std::fs::read_to_string(new.join(query_module("read_widget"))).unwrap();
    assert!(
        read.contains("raise \"TODO: implement read-widget query"),
        "a read query's body is the spec's 1%:\n{read}"
    );
    assert!(
        read.contains("@spec new(String.t())"),
        "the declared `parameters.oneOf` types the parameter:\n{read}"
    );
    assert!(
        !read.contains("alias Sportipedia.Support.JSONAPI.QueryBuilder"),
        "a marker body names nothing to alias:\n{read}"
    );
    let collection = std::fs::read_to_string(new.join(query_module("list_widgets"))).unwrap();
    assert!(
        collection.contains("QueryBuilder.build(query, WidgetReadModel)"),
        "a declared collection ships the working body:\n{collection}"
    );
    assert!(
        collection.contains("alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel"),
        "and the aliases that body names:\n{collection}"
    );

    // pickup: running the port over the oracle-produced tree changes nothing
    let before: Vec<Vec<u8>> = written
        .iter()
        .map(|path| std::fs::read(old.join(path)).unwrap())
        .collect();
    for args in &sequence {
        run_gen(binary, &old, args);
    }
    for (path, bytes) in written.iter().zip(&before) {
        assert_eq!(
            &std::fs::read(old.join(path)).unwrap(),
            bytes,
            "the port rewrote a file the oracle produced: {path}"
        );
    }

    // A marker an earlier run left under a declared collection: the merge owns
    // the notice, the operator owns the edit. Neither tool rewrites the line,
    // pushes an alias into a raising body, or appends a second clause, and
    // both state the same gap.
    let standing = query_module("list_widgets");
    for root in [&old, &new] {
        std::fs::write(root.join(&standing), STANDING_MARKER).unwrap();
    }
    let (oracle_ok, oracle_report) = run_gen_out(&oracle, &old, &["query", "list-widgets"]);
    let (port_ok, port_report) = run_gen_out(binary, &new, &["query", "list-widgets"]);
    assert!(oracle_ok && port_ok, "a stale notice is not a failure");
    for report in [&oracle_report, &port_report] {
        assert!(
            report.contains("Outdated"),
            "the gap is reported:\n{report}"
        );
        assert!(
            report.contains("replace the body with QueryBuilder.build(query, WidgetReadModel) and alias that read model and Sportipedia.Support.JSONAPI.QueryBuilder"),
            "with the exact edit to make:\n{report}"
        );
    }
    for root in [&old, &new] {
        assert_eq!(
            std::fs::read_to_string(root.join(&standing)).unwrap(),
            STANDING_MARKER,
            "the standing marker survives the run"
        );
    }

    // and the fixed-shape verdict: both binaries refuse a template, the
    // operation being the model's declaration alone
    let (ok, out) = run_gen_out(
        &oracle,
        &old,
        &["query", "list-widgets", "--template", "read"],
    );
    assert!(!ok, "the oracle refuses --template for a query");
    assert!(
        out.contains("query is fixed — it takes no --template (remove it)"),
        "oracle: {out}"
    );
    let (ok, out) = run_gen_out(
        binary,
        &new,
        &["query", "list-widgets", "--template", "read"],
    );
    assert!(!ok, "the port refuses it the same way");
    assert!(
        out.contains("query is fixed — it takes no --template (remove it)"),
        "port: {out}"
    );

    let _ = std::fs::remove_dir_all(&old);
    let _ = std::fs::remove_dir_all(&new);
}

/// The lookup query behind the widget's `unique-slug` invariant, as the
/// oracle's `internal_api` run leaves it. `SpGen.generators/0` holds no
/// `lookup_query` entry, so the blueprint is reached through the internal
/// API's `dependencies/1` and the port's CLI cannot address it either: the
/// port runs through `engine::run` with that one module.
const LOOKUP_QUERY: &str =
    "services/api/lib/sportipedia/catalog/equipment/widget/queries/widget_by_slug.ex";

#[test]
fn lookup_query_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };

    // the oracle: the generator that pulls the lookup query as a dependency
    let old = sandbox("oracle");
    run_gen(&oracle, &old, &["internal_api", "read-model.widget"]);

    // the port: the same blueprint, planned directly, with the project's
    // formatter pass afterwards
    let new = sandbox("port");
    let modules: Vec<&dyn sparch_elixir::plan::Blueprint> =
        vec![&sparch_elixir::blueprints::lookup_query::LookupQuery];
    let run = |root: &std::path::Path| {
        let opts = sparch_elixir::engine::RunOptions {
            root: Some(root.to_string_lossy().to_string()),
            ..Default::default()
        };
        sparch_elixir::engine::run(&modules, &opts, "read-model.widget", root)
            .expect("the lookup query run")
    };

    let created: Vec<String> = run(&new)
        .into_iter()
        .filter_map(|row| match row {
            sparch_elixir::engine::Row::Created(path) => Some(path),
            _ => None,
        })
        .collect();
    assert!(
        created.contains(&LOOKUP_QUERY.to_string()),
        "the lookup query is created by its own blueprint: {created:?}"
    );
    assert!(
        created.contains(&READ_MODEL.to_string()),
        "with the read model it reads, planned as its dependency: {created:?}"
    );
    for path in &created {
        format_with_elixir(&new.join("services/api"), &new.join(path));
    }

    let oracle_text = std::fs::read_to_string(old.join(LOOKUP_QUERY)).unwrap();
    let port_text = std::fs::read_to_string(new.join(LOOKUP_QUERY)).unwrap();
    assert_eq!(
        port_text, oracle_text,
        "the lookup query file differs\n--- oracle\n{oracle_text}\n--- port\n{port_text}"
    );

    // pickup: the port over the oracle-produced tree changes nothing
    let before = std::fs::read(old.join(LOOKUP_QUERY)).unwrap();
    run(&old);
    assert_eq!(
        std::fs::read(old.join(LOOKUP_QUERY)).unwrap(),
        before,
        "the port rewrote the lookup query the oracle produced"
    );

    let _ = std::fs::remove_dir_all(&old);
    let _ = std::fs::remove_dir_all(&new);
}

/// The internal API module of the widget citizen.
const INTERNAL_API: &str = "services/api/lib/sportipedia/catalog/equipment/widget/internal.ex";
/// Every file the `internal_api` generator writes for the widget citizen:
/// the internal module itself, the lookup query its accessor delegates to
/// and the read model both of them read (created through the blueprint's
/// dependency expansion). The oracle's creating run also touches two
/// citizens through registry groups this port does not sweep yet — the
/// fixture projection (wave 10) and the command router aliases (wave 5);
/// those files belong to their own waves' parity gates, and the port leaves
/// them alone until then.
fn internal_api_paths() -> Vec<String> {
    vec![
        INTERNAL_API.to_string(),
        LOOKUP_QUERY.to_string(),
        READ_MODEL.to_string(),
    ]
}

/// The internal module of a tree that has no read model: the oracle's own
/// module header with nothing under it, the state a human or an interrupted
/// build leaves behind.
const INTERNAL_SHELL: &str =
    "defmodule Sportipedia.Catalog.Equipment.Widget.WidgetInternal do\nend\n";

#[test]
fn internal_api_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");

    // Addressed from the aggregate: `InternalAPI.source_kinds` accepts the
    // read model too, and a bare `widget` naming both stays ambiguous — the
    // oracle refuses it, so `aggregate.widget` is the canonical driver.
    // The generator is fixed-shape, so no run carries `--template`.
    let args = ["internal_api", "aggregate.widget"];

    // the oracle: formats inside its own run
    let old = sandbox("oracle");
    run_gen(&oracle, &old, &args);

    // the port: splice now, format once — exactly what the mix binding does
    let new = sandbox("port");
    let (port_ok, port_out) = run_gen_out(binary, &new, &args);
    assert!(port_ok, "port run failed: {port_out}");

    // the wiring really exercises the dependency path: the run creates the
    // lookup query and the read model beside its own module
    for path in internal_api_paths() {
        assert!(
            port_out.contains(&sparch_elixir::report::display_path(&path)),
            "the run must report {path}:\n{port_out}"
        );
    }

    let written = internal_api_paths();
    for path in &written {
        format_with_elixir(&new.join("services/api"), &new.join(path));
    }

    // every file the generator wrote matches, byte for byte
    for path in &written {
        let oracle_text = std::fs::read_to_string(old.join(path)).unwrap();
        let port_text = std::fs::read_to_string(new.join(path)).unwrap();
        assert_eq!(port_text, oracle_text, "internal_api file differs: {path}");
    }

    // the shape: the by_id lookup, the accessor's lowercasing delegation,
    // and the three aliases the clauses need to compile
    let internal = std::fs::read_to_string(new.join(INTERNAL_API)).unwrap();
    assert!(
        internal.contains("def widget_by_id(id) do\n    Repo.get(WidgetReadModel, id)"),
        "the by_id lookup reads through the Repo:\n{internal}"
    );
    assert!(
        internal.contains("def widget_by_slug(slug) do\n    slug\n    |> String.downcase()"),
        "the accessor lowercases before delegating:\n{internal}"
    );
    for alias in [
        "alias Sportipedia.Catalog.Equipment.Widget.Queries.WidgetBySlug",
        "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel",
        "alias Sportipedia.Catalog.Repo",
    ] {
        assert!(
            internal.contains(alias),
            "the clause aliases are there:\n{internal}"
        );
    }

    // pickup: running the port over the oracle-produced tree changes nothing
    let before: Vec<Vec<u8>> = written
        .iter()
        .map(|path| std::fs::read(old.join(path)).unwrap())
        .collect();
    run_gen(binary, &old, &args);
    for (path, bytes) in written.iter().zip(&before) {
        assert_eq!(
            &std::fs::read(old.join(path)).unwrap(),
            bytes,
            "the port rewrote a file the oracle produced: {path}"
        );
    }

    // A deferral, on trees where the lookup surface stands but its read
    // model never arrived: `query read-widget` reads a marker body that
    // delegates to nothing, so it plans no read model — the closure sweep
    // backfills only what waits for nothing (the Repo alias), and the rest
    // keeps waiting with the generators to run named. Both tools state the
    // same row and land the same bytes.
    let dold = sandbox("oracle-defer");
    let dnew = sandbox("port-defer");
    for root in [&dold, &dnew] {
        let dir = root.join(INTERNAL_API).parent().unwrap().to_path_buf();
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(root.join(INTERNAL_API), INTERNAL_SHELL).unwrap();
    }
    let (o_ok, o_out) = run_gen_out(&oracle, &dold, &["query", "read-widget"]);
    let (p_ok, p_out) = run_gen_out(binary, &dnew, &["query", "read-widget"]);
    assert!(o_ok && p_ok, "a deferral is guidance, not a failure");
    let expected =
        "catalog/equipment/widget/internal.ex  skipped: sparch internal_api, sparch read_model";
    assert!(o_out.contains(expected), "oracle report:\n{o_out}");
    assert!(p_out.contains(expected), "port report:\n{p_out}");
    format_with_elixir(&dnew.join("services/api"), &dnew.join(INTERNAL_API));
    assert_eq!(
        std::fs::read_to_string(dnew.join(INTERNAL_API)).unwrap(),
        std::fs::read_to_string(dold.join(INTERNAL_API)).unwrap(),
        "the backfilled shell must match"
    );

    for root in [&old, &new, &dold, &dnew] {
        let _ = std::fs::remove_dir_all(root);
    }
}

// ---- wave 5: command ------------------------------------------------------------------

/// The command module file of one widget command.
fn command_module(snake: &str) -> String {
    format!("services/api/lib/sportipedia/catalog/equipment/widget/operations/{snake}/command.ex")
}

/// Every file the four widget command runs write into a fresh copy of the
/// fixtures repo: the four command modules and their operation test files,
/// the validators the commands' dependency expansion creates, the internal
/// API those validators call plus the lookup query and read model behind
/// it, and the two registration hosts — the composite router (merged into
/// the fixture's gadget router) and the subdomain application, which the
/// fixture lacks and the first run creates.
///
/// Files owned by unported generators are excluded here the way the
/// `internal_api` gate excluded them: the test-support fixture projection
/// (wave 10) that the oracle's first creating run writes into
/// `services/api/test/support/`, and the files the oracle's sweep only
/// reports as waiting and never writes — the web router (wave 13) and the
/// subdomain supervisor (wave 7).
fn command_paths() -> Vec<String> {
    let mut paths = Vec::new();
    for snake in [
        "create_widget",
        "edit_widget",
        "archive_widget",
        "note_widget",
    ] {
        paths.push(command_module(snake));
        paths.push(operation_test(snake));
    }
    for snake in ["at_most_one_owner", "unique_slug", "widget_exists"] {
        paths.push(format!(
            "services/api/lib/sportipedia/catalog/equipment/widget/validators/{snake}.ex"
        ));
    }
    paths.push(INTERNAL_API.to_string());
    paths.push(LOOKUP_QUERY.to_string());
    paths.push(READ_MODEL.to_string());
    paths.push("services/api/lib/sportipedia/catalog/equipment/router.ex".to_string());
    paths.push("services/api/lib/sportipedia/catalog/application.ex".to_string());
    paths
}

/// The report lines about citizens this wave's generators own. Lines for
/// the unported generators' files are dropped — the oracle states their
/// deferrals, the port cannot until their waves land.
fn command_report_lines(out: &str) -> Vec<String> {
    let path_of = |t: &str| t.split_whitespace().next().unwrap_or("").to_string();
    let unowned_item = |t: &str| {
        let path = path_of(t);
        path == "router.ex"
            || path == "catalog/supervisor.ex"
            || path.starts_with("services/api/test/support/")
    };
    let mut sections: Vec<(String, Vec<String>)> = Vec::new();
    let mut last_owned = false;
    for line in out.lines() {
        if line.is_empty() {
            continue;
        }
        if !line.starts_with(' ') {
            sections.push((line.to_string(), Vec::new()));
            continue;
        }
        let trimmed = line.trim();
        // detail lines (`    - …`) inherit the ownership of the item above
        let owned = if trimmed.starts_with("- ") {
            last_owned
        } else {
            !unowned_item(trimmed)
        };
        last_owned = owned;
        if owned && let Some((_, items)) = sections.last_mut() {
            items.push(line.to_string());
        }
    }
    sections.retain(|(_, items)| !items.is_empty());
    sections
        .into_iter()
        .flat_map(|(heading, items)| std::iter::once(heading).chain(items))
        .collect()
}

#[test]
fn command_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");

    // One command per operation shape the corpus declares, run in the same
    // order on both sides: `create` (the generated id is internal, so the
    // command never validates it; presence on the required data, the
    // uniqueness pair, the two rule pairs), `update` (the caller provides
    // the id: presence AND the existence check, everything else partial),
    // `delete` (the id alone) and the declared `none` (`note-widget` —
    // materialization undecided, the id and comment still addressed).
    // The first run creates the dependency chain (validators, internal
    // API, lookup query, read model), the operation test files, and the
    // application shell the fixture lacks; the later ones merge into them.
    let sequence: Vec<Vec<&str>> = vec![
        vec!["command", "create-widget"],
        vec!["command", "edit-widget"],
        vec!["command", "archive-widget"],
        vec!["command", "note-widget"],
    ];

    // the oracle: formats inside its own run
    let old = sandbox("oracle");
    let mut old_reports: Vec<String> = Vec::new();
    for args in &sequence {
        let (ok, out) = run_gen_out(&oracle, &old, args);
        assert!(ok, "oracle run failed: {out}");
        old_reports.push(out);
    }

    // the port: splice now, format once — exactly what the mix binding does
    let new = sandbox("port");
    let mut new_reports: Vec<String> = Vec::new();
    for args in &sequence {
        let (ok, out) = run_gen_out(binary, &new, args);
        assert!(ok, "port run failed: {out}");
        new_reports.push(out);
    }

    let written = command_paths();
    for path in &written {
        format_with_elixir(&new.join("services/api"), &new.join(path));
    }

    // every file the generators wrote matches, byte for byte
    for path in &written {
        let oracle_text = std::fs::read_to_string(old.join(path)).unwrap();
        let port_text = std::fs::read_to_string(new.join(path)).unwrap();
        assert_eq!(port_text, oracle_text, "command file differs: {path}");
    }

    // the report rows: runs 2–4 state equal text for the citizens this
    // wave owns (gates, deferrals, the router notes, the Unresolved rules
    // included)
    for i in 1..sequence.len() {
        assert_eq!(
            command_report_lines(&old_reports[i]),
            command_report_lines(&new_reports[i]),
            "run {} report rows differ",
            i + 1
        );
    }
    // Run 1 differs in exactly two documented notes, both owned by
    // generators of later waves: the waiting `public_api` describe
    // (wave 9) on the operation test file, and the extra `sparch command`
    // on the shared router — the oracle keeps a sweep round's deferred
    // rows only because the test_support projection (wave 10) wrote a
    // file that round, and the port has no such write yet.
    let mut run1 = command_report_lines(&old_reports[0]);
    let raw = run1.clone();
    for line in run1.iter_mut() {
        *line = line.replace("  skipped: sparch public_api", "");
        *line = line.replace(
            "skipped: sparch aggregate, sparch command, sparch command_handler",
            "skipped: sparch aggregate, sparch command_handler",
        );
    }
    assert_ne!(raw, run1, "the oracle must really carry those notes");
    assert_eq!(run1, command_report_lines(&new_reports[0]));

    // the shapes really are the shapes
    let create = std::fs::read_to_string(new.join(command_module("create_widget"))).unwrap();
    assert!(
        create.contains("validates :slug, presence: true, by: [function: &UniqueSlug.validate/2, allow_nil: true]"),
        "uniqueness rides with presence:\n{create}"
    );
    assert!(
        create.contains(
            "validates :coachId, by: [function: &AtMostOneOwner.validate/2, allow_nil: true]"
        ),
        "the rule pair skips an absent value:\n{create}"
    );
    assert!(
        !create.contains("validates :id"),
        "the generated (internal) id owes no line:\n{create}"
    );
    assert!(
        !create.contains("allow_blank"),
        "no existence check guards a create command:\n{create}"
    );
    let archive = std::fs::read_to_string(new.join(command_module("archive_widget"))).unwrap();
    assert!(
        archive.contains(
            "# `allow_blank` keeps the existence check off an id the caller never sent:\n  # an absent address is `presence`'s to reject, and a `:not_found` for it would\n  # turn the 422 the client can act on into a 404 for a resource nobody named.\n  validates :id, presence: true, by: [function: &WidgetExists.validate/2, allow_blank: true]"
        ),
        "the exists shape says why:\n{archive}"
    );
    let exists =
        std::fs::read_to_string(new.join(
            "services/api/lib/sportipedia/catalog/equipment/widget/validators/widget_exists.ex",
        ))
        .unwrap();
    assert!(
        exists.contains("alias Sportipedia.Support.Validators.UuidValidator"),
        "the guard's alias rides inside the internal-API alias unit:\n{exists}"
    );
    assert!(
        exists.contains("if UuidValidator.valid_uuid?(id) do"),
        "the lookup sits behind the guard:\n{exists}"
    );
    let scaffold = std::fs::read_to_string(new.join(
        "services/api/lib/sportipedia/catalog/equipment/widget/validators/at_most_one_owner.ex",
    ))
    .unwrap();
    assert!(
        scaffold.contains("raise \"TODO: implement the at-most-one-owner validator"),
        "the rule shape is a scaffold:\n{scaffold}"
    );
    assert!(
        !scaffold.contains("alias Sportipedia.Catalog.Equipment.Widget.WidgetInternal"),
        "a scaffold calls no query, so no internal API joins its file:\n{scaffold}"
    );
    // registration hosts: the router got the command aliases (sorted) but
    // dispatch and identify still wait for the unported handler and the
    // absent aggregate; the application shell was created and got its
    // router line
    let router = std::fs::read_to_string(
        new.join("services/api/lib/sportipedia/catalog/equipment/router.ex"),
    )
    .unwrap();
    assert!(
        router.contains("alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget"),
        "the command alias lands once its file exists:\n{router}"
    );
    assert!(
        !router.contains("dispatch CreateWidget"),
        "dispatch waits for the handler (sparch command_handler):\n{router}"
    );
    let application =
        std::fs::read_to_string(new.join("services/api/lib/sportipedia/catalog/application.ex"))
            .unwrap();
    assert!(
        application.contains("use Commanded.Application, otp_app: :sportipedia"),
        "the application shell is unit-created:\n{application}"
    );
    assert!(
        application.contains("router Sportipedia.Catalog.Equipment.Router"),
        "and its router line lands the moment the router exists:\n{application}"
    );

    // pickup: running the port over the oracle-produced tree changes nothing
    let before: Vec<Vec<u8>> = written
        .iter()
        .map(|path| std::fs::read(old.join(path)).unwrap())
        .collect();
    for args in &sequence {
        run_gen(binary, &old, args);
    }
    for (path, bytes) in written.iter().zip(&before) {
        assert_eq!(
            &std::fs::read(old.join(path)).unwrap(),
            bytes,
            "the port rewrote a file the oracle produced: {path}"
        );
    }

    // A line that is present but does not carry everything the model
    // states now is never appended (Vex keys validations per field): both
    // tools report the same gap with the same text and leave the bytes to
    // the operator.
    let standing = command_module("create_widget");
    let trimmed: String = {
        let text = std::fs::read_to_string(old.join(&standing)).unwrap();
        let trimmed = text.replace(
            ", by: [function: &UniqueSlug.validate/2, allow_nil: true]",
            "",
        );
        assert_ne!(trimmed, text, "the fixture line carries the pair");
        trimmed
    };
    for root in [&old, &new] {
        std::fs::write(root.join(&standing), &trimmed).unwrap();
    }
    let (o_ok, o_out) = run_gen_out(&oracle, &old, &["command", "create-widget"]);
    let (p_ok, p_out) = run_gen_out(binary, &new, &["command", "create-widget"]);
    assert!(o_ok && p_ok, "an Outdated row is guidance, not a failure");
    for report in [&o_out, &p_out] {
        assert!(
            report.contains(
                "- validates slug: add by: [function: &UniqueSlug.validate/2, allow_nil: true]"
            ),
            "the gap is stated with the exact part to add:\n{report}"
        );
    }
    assert_eq!(
        command_report_lines(&o_out),
        command_report_lines(&p_out),
        "oracle:\n{o_out}\nport:\n{p_out}"
    );
    for root in [&old, &new] {
        assert_eq!(
            std::fs::read_to_string(root.join(&standing)).unwrap(),
            trimmed,
            "the standing line survives untouched"
        );
    }

    // A forced `--template` over a declared shape: `create-widget` declares
    // create; run as update the caller provides the id, so the line that
    // the internal id owed appears. Fresh trees, one run each.
    let fold = sandbox("oracle-force");
    let fnew = sandbox("port-force");
    run_gen(
        &oracle,
        &fold,
        &["command", "create-widget", "--template", "update"],
    );
    run_gen(
        binary,
        &fnew,
        &["command", "create-widget", "--template", "update"],
    );
    for path in [
        command_module("create_widget"),
        operation_test("create_widget"),
        "services/api/lib/sportipedia/catalog/equipment/router.ex".to_string(),
        "services/api/lib/sportipedia/catalog/application.ex".to_string(),
    ] {
        format_with_elixir(&fnew.join("services/api"), &fnew.join(&path));
        assert_eq!(
            std::fs::read_to_string(fnew.join(&path)).unwrap(),
            std::fs::read_to_string(fold.join(&path)).unwrap(),
            "forced-update file differs: {path}"
        );
    }
    let forced = std::fs::read_to_string(fnew.join(command_module("create_widget"))).unwrap();
    assert!(
        forced.contains("validates :id, presence: true"),
        "the provided id answers to presence now:\n{forced}"
    );

    // and the `--template` refusals, from the engine's own vocabulary:
    // a template outside the command shapes, and the declared-operation
    // requirement of a command that states none
    for args in [
        vec!["command", "create-widget", "--template", "read"],
        vec!["command", "catalog-apparatus"],
    ] {
        let (o_ok, o_out) = run_gen_out(&oracle, &old, &args);
        let (p_ok, p_out) = run_gen_out(binary, &new, &args);
        assert!(!o_ok && !p_ok, "both refuse: {args:?}");
        // the refusal sentences are compared with each tool's sandbox
        // root masked out (the message names the model file absolutely)
        let head = |out: &str, root: &std::path::Path| -> String {
            out.lines()
                .next()
                .unwrap_or("")
                .replace(&root.display().to_string(), "<root>")
        };
        assert_eq!(
            head(&o_out, &old),
            head(&p_out, &new),
            "refusal text differs: {args:?}"
        );
    }

    for root in [&old, &new, &fold, &fnew] {
        let _ = std::fs::remove_dir_all(root);
    }
}

// ---- wave 6: command_handler --------------------------------------------------------------

/// The command handler module of one widget command.
fn handler_module(snake: &str) -> String {
    format!("services/api/lib/sportipedia/catalog/equipment/widget/operations/{snake}/handler.ex")
}

/// Every file the wave-6 sequence writes into a fresh copy of the fixtures
/// repo. The three handler modules and the operation test files their
/// `describe "Command Handler"` lands in. The registration hosts the handler
/// unblocks, which are the composite router with its `identify`/`dispatch`
/// entries and the subdomain application. And the citizens the sequence
/// generates ahead of them: the six events, the aggregate, the three commands
/// with their validators, internal API, lookup query and read model.
///
/// Files owned by unported generators are excluded here the way the
/// `internal_api` and `command` gates exclude them: the test-support fixture
/// projection (wave 10) the oracle's creating runs write into
/// `services/api/test/support/`, and the files the oracle only reports as
/// waiting, which are the web router (wave 13) and the subdomain supervisor
/// (wave 7).
fn command_handler_paths() -> Vec<String> {
    let mut paths = Vec::new();
    for snake in [
        "widget_archived",
        "widget_created",
        "widget_edited",
        "widget_noted",
        "widget_relabelled",
        "widget_rename_logged",
    ] {
        paths.push(format!(
            "services/api/lib/sportipedia/catalog/equipment/widget/events/{snake}.ex"
        ));
        paths.push(format!(
            "services/api/test/sportipedia/catalog/equipment/widget/events/{snake}_test.exs"
        ));
    }
    paths.push("services/api/lib/sportipedia/catalog/equipment/widget/aggregate.ex".to_string());
    for snake in ["create_widget", "edit_widget", "relabel_widget"] {
        paths.push(command_module(snake));
        paths.push(operation_test(snake));
        paths.push(handler_module(snake));
    }
    for snake in ["at_most_one_owner", "unique_slug", "widget_exists"] {
        paths.push(format!(
            "services/api/lib/sportipedia/catalog/equipment/widget/validators/{snake}.ex"
        ));
    }
    paths.push(INTERNAL_API.to_string());
    paths.push(LOOKUP_QUERY.to_string());
    paths.push(READ_MODEL.to_string());
    paths.push("services/api/lib/sportipedia/catalog/equipment/router.ex".to_string());
    paths.push("services/api/lib/sportipedia/catalog/application.ex".to_string());
    paths
}

/// The report lines about the citizens one handler run owns. That is the
/// handler module it writes and that command's own operation test file (both
/// begin with `operations/<snake>`), the two registration hosts, and the
/// command's unresolved rules.
///
/// Rows for other citizens are dropped. A test file a run only defers on
/// states the LAST group that waited for it, and the oracle's last group is
/// `public_api` (wave 9, not ported here), so the oracle can state a row the
/// port has no group to state at all. On the one line both tools do state,
/// the notes differ for the same reason, so the note is cut off there. Each
/// tool's own note text is asserted on the raw report instead.
fn handler_report_lines(out: &str, kebab: &str, snake: &str) -> Vec<String> {
    let handler_item = format!("catalog/equipment/widget/operations/{snake}");
    let test_item = format!("catalog/equipment/widget/operations/{snake}_test.exs");
    let element_item = format!("command.{kebab}");
    let owned_item = |t: &str| {
        t.starts_with(handler_item.as_str())
            || t == "catalog/equipment/router.ex"
            || t == "catalog/application.ex"
            || t == element_item
    };
    let path_of = |t: &str| t.split_whitespace().next().unwrap_or("").to_string();
    let mut sections: Vec<(String, Vec<String>)> = Vec::new();
    let mut last_owned = false;
    for line in out.lines() {
        if line.is_empty() {
            continue;
        }
        if !line.starts_with(' ') {
            sections.push((line.to_string(), Vec::new()));
            continue;
        }
        let trimmed = line.trim();
        // detail lines (`    - …`) inherit the ownership of the item above
        let owned = if trimmed.starts_with("- ") {
            last_owned
        } else {
            owned_item(&path_of(trimmed))
        };
        last_owned = owned;
        if owned {
            let kept = if trimmed.starts_with(test_item.as_str()) {
                line.split("  skipped:").next().unwrap_or(line).to_string()
            } else {
                line.to_string()
            };
            if let Some((_, items)) = sections.last_mut() {
                items.push(kept);
            }
        }
    }
    sections.retain(|(_, items)| !items.is_empty());
    sections
        .into_iter()
        .flat_map(|(heading, items)| std::iter::once(heading).chain(items))
        .collect()
}

/// The report line a path is stated on, if the run states it at all.
fn report_line(out: &str, path: &str) -> String {
    out.lines()
        .find(|line| line.trim_start().starts_with(path))
        .unwrap_or_else(|| panic!("no report line for {path}:\n{out}"))
        .to_string()
}

#[test]
fn command_handler_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");

    // The known-good build order, run in the same sequence on both sides. The
    // events and the aggregate come first because the handler's aliases and
    // its `handle/2` are gated on them, and its command test file is gated on
    // the command. Three handler shapes. `create-widget` publishes one fact,
    // `edit-widget` is the update shape, and `relabel-widget` publishes two
    // facts, which is one alias per event under one `handle/2` spec.
    let sequence: Vec<Vec<&str>> = vec![
        vec!["event", "widget-created"],
        vec!["event", "widget-edited"],
        vec!["event", "widget-archived"],
        vec!["event", "widget-relabelled"],
        vec!["event", "widget-noted"],
        vec!["event", "widget-rename-logged"],
        vec!["aggregate", "widget"],
        vec!["command", "create-widget"],
        vec!["command", "edit-widget"],
        vec!["command", "relabel-widget"],
        vec!["command_handler", "create-widget"],
        vec!["command_handler", "edit-widget"],
        vec!["command_handler", "relabel-widget"],
    ];
    // the last three runs of the sequence are the handler runs this wave drives
    const HANDLED: usize = 10;

    // the oracle: formats inside its own run
    let old = sandbox("oracle");
    let mut old_reports: Vec<String> = Vec::new();
    for args in &sequence {
        let (ok, out) = run_gen_out(&oracle, &old, args);
        assert!(ok, "oracle run failed: {args:?}\n{out}");
        old_reports.push(out);
    }

    // the port: splice now, format once — exactly what the mix binding does
    let new = sandbox("port");
    let mut new_reports: Vec<String> = Vec::new();
    for args in &sequence {
        let (ok, out) = run_gen_out(binary, &new, args);
        assert!(ok, "port run failed: {args:?}\n{out}");
        new_reports.push(out);
    }
    eprintln!(
        "--- oracle's last handler run:\n{}",
        old_reports[sequence.len() - 1]
    );

    let written = command_handler_paths();
    for path in &written {
        format_with_elixir(&new.join("services/api"), &new.join(path));
    }

    // every file the generators wrote matches, byte for byte
    for path in &written {
        let oracle_text = std::fs::read_to_string(old.join(path)).unwrap();
        let port_text = std::fs::read_to_string(new.join(path)).unwrap();
        assert_eq!(
            port_text, oracle_text,
            "command_handler file differs: {path}"
        );
    }

    // the three handler runs report the same rows for the citizens each run
    // owns (the router's surviving `skipped:` note included, which is the
    // last deferred row of that path in both tools)
    let shapes = [
        ("create-widget", "create_widget"),
        ("edit-widget", "edit_widget"),
        ("relabel-widget", "relabel_widget"),
    ];
    for (n, (kebab, snake)) in shapes.iter().enumerate() {
        let i = HANDLED + n;
        assert_eq!(
            handler_report_lines(&old_reports[i], kebab, snake),
            handler_report_lines(&new_reports[i], kebab, snake),
            "run {} ({kebab}) report rows differ\n--- oracle\n{}\n--- port\n{}",
            i + 1,
            old_reports[i],
            new_reports[i]
        );
    }

    // The note the report filter cuts is each tool's own truth. On a test
    // file whose handler is still missing, both tools state the `public_api`
    // wait: with the port's own public_api group in the sweep, that is the
    // last group deferring on the file on both sides, and the handler wait
    // ranks ahead of it.
    for (report, tool) in [
        (&old_reports[HANDLED], "oracle"),
        (&new_reports[HANDLED], "port"),
    ] {
        assert!(
            report_line(
                report,
                "catalog/equipment/widget/operations/edit_widget_test.exs"
            )
            .contains("skipped: sparch public_api"),
            "{tool} states the public_api wait:\n{report}"
        );
    }

    // the shapes really are the shapes
    let create = std::fs::read_to_string(new.join(handler_module("create_widget"))).unwrap();
    assert!(
        create.contains("@behaviour Commanded.Commands.Handler"),
        "the behaviour lands with the file:\n{create}"
    );
    assert!(
        create.contains(
            "@spec handle(WidgetAggregate.t(), CreateWidget.t()) :: WidgetCreated.t() | [WidgetCreated.t()]"
        ),
        "the spec promises the published fact:\n{create}"
    );
    assert!(
        create.contains("def handle(%WidgetAggregate{} = aggregate, %CreateWidget{} = cmd) do"),
        "the head matches both citizens:\n{create}"
    );
    let relabel = std::fs::read_to_string(new.join(handler_module("relabel_widget"))).unwrap();
    for alias in [
        "alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetRelabelled",
        "alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetRenameLogged",
    ] {
        assert!(
            relabel.contains(alias),
            "one alias per published event:\n{relabel}"
        );
    }
    let test_file = std::fs::read_to_string(new.join(operation_test("create_widget"))).unwrap();
    assert!(
        test_file.contains(
            "describe \"Command Handler\" do\n    test \"handles CreateWidget command and returns WidgetCreated event\" do"
        ),
        "the describe rides in the command's own test file:\n{test_file}"
    );
    assert!(
        test_file.contains("events = CreateWidgetHandler.handle(%WidgetAggregate{}, cmd)"),
        "the call it exercises:\n{test_file}"
    );
    let router = std::fs::read_to_string(
        new.join("services/api/lib/sportipedia/catalog/equipment/router.ex"),
    )
    .unwrap();
    for command in ["CreateWidget", "EditWidget", "RelabelWidget"] {
        assert!(
            router.contains(&format!(
                "dispatch {command}, to: {command}Handler, aggregate: WidgetAggregate"
            )),
            "the handler run unblocks the router registration for {command}:\n{router}"
        );
    }

    // pickup: running the port over the oracle-produced tree changes nothing
    let before: Vec<Vec<u8>> = written
        .iter()
        .map(|path| std::fs::read(old.join(path)).unwrap())
        .collect();
    for args in &sequence[HANDLED..] {
        run_gen(binary, &old, args);
    }
    for (path, bytes) in written.iter().zip(&before) {
        assert_eq!(
            &std::fs::read(old.join(path)).unwrap(),
            bytes,
            "the port rewrote a file the oracle produced: {path}"
        );
    }

    // the handler is fixed-shape: both binaries refuse a template with the
    // engine's own sentence
    let (o_ok, o_out) = run_gen_out(
        &oracle,
        &old,
        &["command_handler", "create-widget", "--template", "create"],
    );
    assert!(!o_ok, "the oracle refuses --template for a handler");
    assert!(
        o_out.contains("command_handler is fixed — it takes no --template (remove it)"),
        "oracle: {o_out}"
    );
    let (p_ok, p_out) = run_gen_out(
        binary,
        &new,
        &["command_handler", "create-widget", "--template", "create"],
    );
    assert!(!p_ok, "the port refuses it the same way");
    assert!(
        p_out.contains("command_handler is fixed — it takes no --template (remove it)"),
        "port: {p_out}"
    );

    // A command whose published fact the model does not hold. The oracle's
    // `CommandHandlerTest.plans/1` renders `<Event>` from that empty list and
    // raises, which kills the run where it stands. The port plans nothing for
    // either handler blueprint, so the run finishes and the handler generator
    // writes no file, which is what the crashed run managed too.
    // `aggregate apparatus` reaches it through the neighborhood sweep, the
    // way wave 3 met it.
    let apparatus = "services/api/lib/sportipedia/catalog/equipment/apparatus/aggregate.ex";
    let dold = sandbox("oracle-noevent");
    let dnew = sandbox("port-noevent");
    let (o_ok, o_out) = run_gen_out(&oracle, &dold, &["aggregate", "apparatus"]);
    let (p_ok, p_out) = run_gen_out(binary, &dnew, &["aggregate", "apparatus"]);
    eprintln!("--- oracle on a command that publishes nothing it can resolve:\n{o_out}");
    assert!(!o_ok, "the oracle dies where the port does not: {o_out}");
    assert!(
        o_out.contains("unresolved placeholder(s) in template: <Event>"),
        "the oracle's crash is the missing event:\n{o_out}"
    );
    assert!(p_ok, "the port finishes its run: {p_out}");
    format_with_elixir(&dnew.join("services/api"), &dnew.join(apparatus));
    assert_eq!(
        std::fs::read_to_string(dnew.join(apparatus)).unwrap(),
        std::fs::read_to_string(dold.join(apparatus)).unwrap(),
        "the file the oracle wrote before it died must match"
    );
    for snake in ["catalog_apparatus", "edit_apparatus", "archive_apparatus"] {
        let handler = format!(
            "services/api/lib/sportipedia/catalog/equipment/apparatus/operations/{snake}/handler.ex"
        );
        for root in [&dold, &dnew] {
            assert!(
                !root.join(&handler).exists(),
                "a command with no event generates no handler: {handler}"
            );
        }
    }

    for root in [&old, &new, &dold, &dnew] {
        let _ = std::fs::remove_dir_all(root);
    }
}

// ---- wave 7: projector ------------------------------------------------------------------

/// The projector module file of the widget constituent.
fn projector_module() -> String {
    "services/api/lib/sportipedia/catalog/equipment/widget/projector.ex".to_string()
}

/// The subdomain supervisor the projector registers its child into.
const SUPERVISOR: &str = "services/api/lib/sportipedia/catalog/supervisor.ex";

/// Every file the three widget projector runs write into a fresh copy of the
/// fixtures repo: the one projector module all three events share, the
/// subdomain supervisor the child registration lands in, and the `describe
/// "Projector"` each projected event's own test file receives. The relabelled
/// event's test file is included because `widget-relabelled` is the second
/// `update` fact the read model declares, and the creating run's closure sweep
/// back-fills its clause into the same projector module and its describe into
/// its own test file, exactly as the oracle does.
///
/// Files owned by unported generators are excluded here the way the earlier
/// gates exclude them: the test-support fixture projection (wave 10), the web
/// router (wave 13), and the operation test files whose surviving note the
/// oracle takes from the unported `public_api` group (wave 9).
fn projector_paths() -> Vec<String> {
    let mut paths = vec![projector_module(), SUPERVISOR.to_string()];
    for snake in [
        "widget_created",
        "widget_edited",
        "widget_archived",
        "widget_relabelled",
    ] {
        paths.push(format!(
            "services/api/test/sportipedia/catalog/equipment/widget/events/{snake}_test.exs"
        ));
    }
    paths
}

/// The report rows a projector run owns: the projector module, the subdomain
/// supervisor, the projected event test files, the command router registration
/// host the closure back-fills, and the driven event's unresolved rules. The
/// rows for the web router and the operation test files are dropped — the
/// oracle states a `skipped: sparch controller` / `skipped: sparch public_api`
/// note there for generators this wave has not ported, and the port states no
/// such row at all. The composite router's note is asserted to be equal,
/// because both tools reach that group through the widget neighborhood.
fn projector_report_lines(out: &str, kebab: &str) -> Vec<String> {
    let owned_item = |t: &str| {
        let path = t.split_whitespace().next().unwrap_or("");
        path == "catalog/equipment/widget/projector.ex"
            || path == "catalog/supervisor.ex"
            || path == "catalog/equipment/router.ex"
            || path.starts_with("catalog/equipment/widget/events/")
            || path == format!("event.{kebab}")
    };
    let mut sections: Vec<(String, Vec<String>)> = Vec::new();
    let mut last_owned = false;
    for line in out.lines() {
        if line.is_empty() {
            continue;
        }
        if !line.starts_with(' ') {
            sections.push((line.to_string(), Vec::new()));
            continue;
        }
        let trimmed = line.trim();
        let owned = if trimmed.starts_with("- ") {
            last_owned
        } else {
            owned_item(trimmed)
        };
        last_owned = owned;
        if owned && let Some((_, items)) = sections.last_mut() {
            items.push(line.to_string());
        }
    }
    sections.retain(|(_, items)| !items.is_empty());
    sections
        .into_iter()
        .flat_map(|(heading, items)| std::iter::once(heading).chain(items))
        .collect()
}

#[test]
fn projector_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");

    // The known-good build order up to the projector. The events come first
    // because the projector's clause and its event alias gate on the event
    // module; the aggregate for the fold; the commands, whose dependency
    // expansion brings the read model and the internal API the clause calls.
    // Three projector shapes: `create` (the insert), `update` (the
    // `get_changes/1` merge the wave-1 event contract feeds) and `delete` (the
    // row removal). `widget-relabelled` is the second `update` fact the read
    // model declares, so the first creating run's closure sweep lands its
    // clause too, which is what the pickup run then finds present.
    let sequence: Vec<Vec<&str>> = vec![
        vec!["event", "widget-created"],
        vec!["event", "widget-edited"],
        vec!["event", "widget-archived"],
        vec!["event", "widget-relabelled"],
        vec!["event", "widget-noted"],
        vec!["event", "widget-rename-logged"],
        vec!["aggregate", "widget"],
        vec!["command", "create-widget"],
        vec!["command", "edit-widget"],
        vec!["command", "relabel-widget"],
        vec!["command_handler", "create-widget"],
        vec!["command_handler", "edit-widget"],
        vec!["command_handler", "relabel-widget"],
        vec!["projector", "widget-created"],
        vec!["projector", "widget-edited"],
        vec!["projector", "widget-archived"],
    ];
    const PROJECTED: usize = 13;

    // the oracle: formats inside its own run
    let old = sandbox("oracle");
    let mut old_reports: Vec<String> = Vec::new();
    for args in &sequence {
        let (ok, out) = run_gen_out(&oracle, &old, args);
        assert!(ok, "oracle run failed: {args:?}\n{out}");
        old_reports.push(out);
    }

    // the port: splice now, format once — exactly what the mix binding does
    let new = sandbox("port");
    let mut new_reports: Vec<String> = Vec::new();
    for args in &sequence {
        let (ok, out) = run_gen_out(binary, &new, args);
        assert!(ok, "port run failed: {args:?}\n{out}");
        new_reports.push(out);
    }

    let written = projector_paths();
    for path in &written {
        format_with_elixir(&new.join("services/api"), &new.join(path));
    }

    // every file the generators wrote matches, byte for byte
    for path in &written {
        let oracle_text = std::fs::read_to_string(old.join(path)).unwrap();
        let port_text = std::fs::read_to_string(new.join(path)).unwrap();
        assert_eq!(port_text, oracle_text, "projector file differs: {path}");
    }

    // the three projector runs report the same rows for the citizens each run
    // owns, the surviving `skipped:` note on the shared files included
    for (n, kebab) in ["widget-created", "widget-edited", "widget-archived"]
        .iter()
        .enumerate()
    {
        let i = PROJECTED + n;
        assert_eq!(
            projector_report_lines(&old_reports[i], kebab),
            projector_report_lines(&new_reports[i], kebab),
            "run {} ({kebab}) report rows differ\n--- oracle\n{}\n--- port\n{}",
            i + 1,
            old_reports[i],
            new_reports[i]
        );
    }

    // the shapes really are the shapes: all three declared effects land in the
    // one shared projector module, each keyed by the effect the read model
    // declares for its event
    let projector = std::fs::read_to_string(new.join(projector_module())).unwrap();
    assert!(
        projector.contains("project %WidgetCreated{} = event, _metadata, fn multi ->"),
        "the create clause inserts the row:\n{projector}"
    );
    assert!(
        projector.contains("attrs = WidgetEdited.get_changes(event)"),
        "the update clause merges the event's changes:\n{projector}"
    );
    assert!(
        projector.contains("Ecto.Multi.delete(:widget_archived, widget)"),
        "the delete clause removes the row:\n{projector}"
    );
    let supervisor = std::fs::read_to_string(new.join(SUPERVISOR)).unwrap();
    assert!(
        supervisor.contains("Sportipedia.Catalog.Equipment.Widget.WidgetProjector"),
        "the projector registers in the subdomain supervisor:\n{supervisor}"
    );
    let test_file = std::fs::read_to_string(new.join(
        "services/api/test/sportipedia/catalog/equipment/widget/events/widget_created_test.exs",
    ))
    .unwrap();
    assert!(
        test_file.contains("describe \"Projector\" do"),
        "the Projector describe rides in the event's own test file:\n{test_file}"
    );

    // pickup: running the port over the oracle-produced tree changes nothing
    let before: Vec<Vec<u8>> = written
        .iter()
        .map(|path| std::fs::read(old.join(path)).unwrap())
        .collect();
    for args in &sequence[PROJECTED..] {
        run_gen(binary, &old, args);
    }
    for (path, bytes) in written.iter().zip(&before) {
        assert_eq!(
            &std::fs::read(old.join(path)).unwrap(),
            bytes,
            "the port rewrote a file the oracle produced: {path}"
        );
    }

    // A declared `none` fact materializes nothing: no clause in the projector,
    // no describe in its test file. `sparch projector widget-noted` reports its
    // own gap row (the effect is declared `none`, so no clause is a decision,
    // not a gap) and writes nothing to the projector module it already owns.
    let (p_ok, p_none) = run_gen_out(binary, &new, &["projector", "widget-noted"]);
    let (o_ok, o_none) = run_gen_out(&oracle, &old, &["projector", "widget-noted"]);
    assert!(p_ok && o_ok, "a declared none is a decision, not a failure");
    assert_eq!(
        projector_report_lines(&o_none, "widget-noted"),
        projector_report_lines(&p_none, "widget-noted"),
        "the declared-none projector run reports the same\n--- oracle\n{o_none}\n--- port\n{p_none}"
    );

    for root in [&old, &new] {
        let _ = std::fs::remove_dir_all(root);
    }
}

// ---- wave 8: policy ------------------------------------------------------------------

/// The widget constituent's policy module, one file for every operation.
const POLICY: &str = "services/api/lib/sportipedia/catalog/equipment/widget/policy.ex";

/// The composite command router the first creating run's closure back-fills.
const COMPOSITE_ROUTER: &str = "services/api/lib/sportipedia/catalog/equipment/router.ex";

/// Every file the seven widget policy runs and the one admin-only run write
/// into a fresh copy of the fixtures repo: the widget policy module the seven
/// operations share, each operation's own test file with the
/// `describe "Policy"` it receives, the position policy module with its three
/// admin clauses, and the command router the creating run's closure back-fills.
///
/// Files owned by unported generators are excluded here the way the earlier
/// gates exclude them: the test-support fixture projection (wave 10) and the
/// web router (wave 13).
fn policy_paths() -> Vec<String> {
    let mut paths = vec![POLICY.to_string()];
    for snake in [
        "create_widget",
        "edit_widget",
        "archive_widget",
        "note_widget",
        "relabel_widget",
        "read_widget",
        "list_widgets",
    ] {
        paths.push(operation_test(snake));
    }
    paths.push("services/api/lib/sportipedia/catalog/athlete/position/policy.ex".to_string());
    paths.push(
        "services/api/test/sportipedia/catalog/athlete/position/operations/archive_position_test.exs"
            .to_string(),
    );
    paths.push(COMPOSITE_ROUTER.to_string());
    paths
}

/// The report rows a policy run owns: the driven citizen's policy module, that
/// operation's own test file, the command router the sweep back-fills, and the
/// driven element's unresolved rules. Rows for other citizens are dropped. A
/// file's surviving `skipped:` note names the LAST group that waited for it,
/// and the web router and the fixture projection belong to generators later
/// waves port.
fn policy_report_lines(out: &str, kebab: &str) -> Vec<String> {
    let snake = kebab.replace('-', "_");
    let owned_item = |t: &str| {
        let path = t.split_whitespace().next().unwrap_or("");
        path.ends_with("widget/policy.ex")
            || path.ends_with("position/policy.ex")
            || path == format!("catalog/equipment/widget/operations/{snake}_test.exs")
            || path == format!("catalog/athlete/position/operations/{snake}_test.exs")
            || path == "catalog/equipment/router.ex"
            || path == format!("command.{kebab}")
            || path == format!("query.{kebab}")
    };
    let mut sections: Vec<(String, Vec<String>)> = Vec::new();
    let mut last_owned = false;
    for line in out.lines() {
        if line.is_empty() {
            continue;
        }
        if !line.starts_with(' ') {
            sections.push((line.to_string(), Vec::new()));
            continue;
        }
        let trimmed = line.trim();
        let owned = if trimmed.starts_with("- ") {
            last_owned
        } else {
            owned_item(trimmed)
        };
        last_owned = owned;
        if owned && let Some((_, items)) = sections.last_mut() {
            items.push(line.to_string());
        }
    }
    sections.retain(|(_, items)| !items.is_empty());
    sections
        .into_iter()
        .flat_map(|(heading, items)| std::iter::once(heading).chain(items))
        .collect()
}

#[test]
fn policy_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");

    // Every operation of the widget citizen, in the same order on both sides:
    // the five commands answer the deny/allow guard pair (`user` is their only
    // actor), the two queries the open clause (`guest` stands among their
    // actors). `archive-position` closes the run: `admin` is its only actor,
    // so the clause is the guest denial, the `is_admin?` allowance and the
    // explicit denial of every other authenticated user. The first run creates
    // the shared policy module and every later run merges its own clause into
    // it, which is what the pickup run then finds present.
    let sequence: Vec<Vec<&str>> = vec![
        vec!["policy", "create-widget"],
        vec!["policy", "edit-widget"],
        vec!["policy", "archive-widget"],
        vec!["policy", "note-widget"],
        vec!["policy", "relabel-widget"],
        vec!["policy", "read-widget"],
        vec!["policy", "list-widgets"],
        vec!["policy", "archive-position"],
    ];

    // the oracle: formats inside its own run
    let old = sandbox("oracle");
    let mut old_reports: Vec<String> = Vec::new();
    for args in &sequence {
        let (ok, out) = run_gen_out(&oracle, &old, args);
        assert!(ok, "oracle run failed: {args:?}\n{out}");
        old_reports.push(out);
    }

    // the port: splice now, format once, exactly what the mix binding does
    let new = sandbox("port");
    let mut new_reports: Vec<String> = Vec::new();
    for args in &sequence {
        let (ok, out) = run_gen_out(binary, &new, args);
        assert!(ok, "port run failed: {args:?}\n{out}");
        new_reports.push(out);
    }

    let written = policy_paths();
    for path in &written {
        format_with_elixir(&new.join("services/api"), &new.join(path));
    }

    // every file the generators wrote matches, byte for byte
    for path in &written {
        let oracle_text = std::fs::read_to_string(old.join(path)).unwrap();
        let port_text = std::fs::read_to_string(new.join(path)).unwrap();
        assert_eq!(port_text, oracle_text, "policy file differs: {path}");
    }

    // the eight runs report the same rows for the citizens each run owns
    for (i, kebab) in [
        "create-widget",
        "edit-widget",
        "archive-widget",
        "note-widget",
        "relabel-widget",
        "read-widget",
        "list-widgets",
        "archive-position",
    ]
    .iter()
    .enumerate()
    {
        assert_eq!(
            policy_report_lines(&old_reports[i], kebab),
            policy_report_lines(&new_reports[i], kebab),
            "run {} ({kebab}) report rows differ\n--- oracle\n{}\n--- port\n{}",
            i + 1,
            old_reports[i],
            new_reports[i]
        );
    }

    // the shapes really are the shapes: three clause families in the two
    // policy modules
    let policy = std::fs::read_to_string(new.join(POLICY)).unwrap();
    assert!(
        policy.contains(
            "def authorize(:create_widget, user, _params) when is_guest?(user), do: :error"
        ),
        "the guest denial of a command:\n{policy}"
    );
    assert!(
        policy
            .contains("def authorize(:create_widget, user, _params) when is_user?(user), do: :ok"),
        "the user allowance of a command:\n{policy}"
    );
    assert!(
        policy.contains("def authorize(:read_widget, _user, _params), do: :ok"),
        "the open clause of a guest's query:\n{policy}"
    );
    let admin = std::fs::read_to_string(
        new.join("services/api/lib/sportipedia/catalog/athlete/position/policy.ex"),
    )
    .unwrap();
    assert!(
        admin.contains(
            "def authorize(:archive_position, user, _params) when is_admin?(user), do: :ok"
        ),
        "the allowance is `is_admin?`, never `is_user?`:\n{admin}"
    );
    assert!(
        admin.contains(
            "def authorize(:archive_position, user, _params) when is_user?(user), do: :error"
        ),
        "every other authenticated user is denied explicitly:\n{admin}"
    );
    let test_file = std::fs::read_to_string(new.join(operation_test("create_widget"))).unwrap();
    assert!(
        test_file.contains("describe \"Policy\" do"),
        "the Policy describe rides in the operation's own test file:\n{test_file}"
    );

    // pickup: running the port over the oracle-produced tree changes nothing
    let before: Vec<Vec<u8>> = written
        .iter()
        .map(|path| std::fs::read(old.join(path)).unwrap())
        .collect();
    for args in &sequence {
        run_gen(binary, &old, args);
    }
    for (path, bytes) in written.iter().zip(&before) {
        assert_eq!(
            &std::fs::read(old.join(path)).unwrap(),
            bytes,
            "the port rewrote a file the oracle produced: {path}"
        );
    }

    for root in [&old, &new] {
        let _ = std::fs::remove_dir_all(root);
    }
}

// ---- wave 9: public_api ---------------------------------------------------------------

/// The widget constituent's public API (port) file, one function per
/// operation.
const PUBLIC_API: &str = "services/api/lib/sportipedia/catalog/equipment/widget/public_api.ex";

/// Every file the seven widget public-API runs write into a fresh copy of the
/// fixtures repo: the one port module the operations share, each operation's
/// own test file with the `describe "Public API"` it receives, the query
/// citizen and the read model the collection run pulls as dependencies, and
/// the command router the creating run's closure back-fills.
///
/// Files owned by unported generators are excluded here the way the earlier
/// gates exclude them: the test-support fixture projection (wave 10) and the
/// web router (wave 13).
fn public_api_paths() -> Vec<String> {
    let mut paths = vec![PUBLIC_API.to_string()];
    for snake in [
        "create_widget",
        "edit_widget",
        "archive_widget",
        "note_widget",
        "relabel_widget",
        "read_widget",
        "list_widgets",
    ] {
        paths.push(operation_test(snake));
    }
    paths.push(query_module("list_widgets"));
    paths.push(READ_MODEL.to_string());
    paths.push(COMPOSITE_ROUTER.to_string());
    paths
}

/// The report rows a public-API run owns: the port module, the driven
/// operation's test file, the query citizen and the read model the collection
/// run creates, the command router the sweep back-fills, and the driven
/// element's unresolved rules. Rows for other citizens are dropped. The
/// oracle states a `skipped: sparch controller` note on the web router and a
/// row for the fixture projection, and the port has no group to state those.
/// On the operation test files the surviving `skipped:` note names the LAST
/// group that waited for the file, which is the next run's generator on one
/// side and an unported generator's group on the other, so the note is cut
/// off there and each tool's own note text is asserted on the raw report.
fn public_api_report_lines(out: &str, kebab: &str) -> Vec<String> {
    let snake = kebab.replace('-', "_");
    let test_item = format!("catalog/equipment/widget/operations/{snake}_test.exs");
    let owned_item = |t: &str| {
        let path = t.split_whitespace().next().unwrap_or("");
        path == "catalog/equipment/widget/public_api.ex"
            || path.starts_with(test_item.as_str())
            || path == "catalog/equipment/widget/queries/list_widgets.ex"
            || path == "catalog/equipment/widget/read_model.ex"
            || path == "catalog/equipment/router.ex"
            || path == format!("command.{kebab}")
            || path == format!("query.{kebab}")
    };
    let mut sections: Vec<(String, Vec<String>)> = Vec::new();
    let mut last_owned = false;
    for line in out.lines() {
        if line.is_empty() {
            continue;
        }
        if !line.starts_with(' ') {
            sections.push((line.to_string(), Vec::new()));
            continue;
        }
        let trimmed = line.trim();
        let owned = if trimmed.starts_with("- ") {
            last_owned
        } else {
            owned_item(trimmed)
        };
        last_owned = owned;
        if owned {
            let kept = if trimmed.starts_with(test_item.as_str()) {
                line.split("  skipped:").next().unwrap_or(line).to_string()
            } else {
                line.to_string()
            };
            if let Some((_, items)) = sections.last_mut() {
                items.push(kept);
            }
        }
    }
    sections.retain(|(_, items)| !items.is_empty());
    sections
        .into_iter()
        .flat_map(|(heading, items)| std::iter::once(heading).chain(items))
        .collect()
}

#[test]
fn public_api_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");

    // The known-good build order up to the port. The commands come first with
    // their dependency chain (validators, internal API, lookup query, read
    // model) because every function body names those citizens; the policy runs
    // precede it as `@generator_order` says. Each run merges its own function
    // into the one shared port file. `list-widgets` carries its query citizen
    // as this blueprint's own dependency, so the collection function lands the
    // moment its query and read model exist.
    let sequence: Vec<Vec<&str>> = vec![
        vec!["command", "create-widget"],
        vec!["command", "edit-widget"],
        vec!["command", "archive-widget"],
        vec!["command", "note-widget"],
        vec!["command", "relabel-widget"],
        vec!["internal_api", "aggregate.widget"],
        vec!["policy", "create-widget"],
        vec!["policy", "edit-widget"],
        vec!["policy", "archive-widget"],
        vec!["policy", "note-widget"],
        vec!["policy", "relabel-widget"],
        vec!["public_api", "create-widget"],
        vec!["public_api", "edit-widget"],
        vec!["public_api", "archive-widget"],
        vec!["public_api", "note-widget"],
        vec!["public_api", "relabel-widget"],
        vec!["public_api", "read-widget"],
        vec!["public_api", "list-widgets"],
    ];
    const PORTED: usize = 11;

    // the oracle: formats inside its own run
    let old = sandbox("oracle");
    let mut old_reports: Vec<String> = Vec::new();
    for args in &sequence {
        let (ok, out) = run_gen_out(&oracle, &old, args);
        assert!(ok, "oracle run failed: {args:?}\n{out}");
        old_reports.push(out);
    }

    // the port: splice now, format once, exactly what the mix binding does
    let new = sandbox("port");
    let mut new_reports: Vec<String> = Vec::new();
    for args in &sequence {
        let (ok, out) = run_gen_out(binary, &new, args);
        assert!(ok, "port run failed: {args:?}\n{out}");
        new_reports.push(out);
    }

    let written = public_api_paths();
    for path in &written {
        format_with_elixir(&new.join("services/api"), &new.join(path));
    }

    // every file the generators wrote matches, byte for byte
    for path in &written {
        let oracle_text = std::fs::read_to_string(old.join(path)).unwrap();
        let port_text = std::fs::read_to_string(new.join(path)).unwrap();
        assert_eq!(port_text, oracle_text, "public_api file differs: {path}");
    }

    // the seven public-API runs report the same rows for the citizens each
    // run owns, the surviving `skipped:` note on the shared files included
    for (n, kebab) in [
        "create-widget",
        "edit-widget",
        "archive-widget",
        "note-widget",
        "relabel-widget",
        "read-widget",
        "list-widgets",
    ]
    .iter()
    .enumerate()
    {
        let i = PORTED + n;
        assert_eq!(
            public_api_report_lines(&old_reports[i], kebab),
            public_api_report_lines(&new_reports[i], kebab),
            "run {} ({kebab}) report rows differ\n--- oracle\n{}\n--- port\n{}",
            i + 1,
            old_reports[i],
            new_reports[i]
        );
    }

    // the shapes really are the shapes: the create generates the id, the
    // update addresses the given one, the delete and the declared `none`
    // return the dispatch result, the read branches on the id format, and the
    // collection names the query citizen
    let port = std::fs::read_to_string(new.join(PUBLIC_API)).unwrap();
    assert!(
        port.contains("cmd = CreateWidget.new(Map.put(params, \"id\", id))"),
        "the create generates the id:\n{port}"
    );
    assert!(
        port.contains("WidgetInternal.widget_by_id(params[:id] || params[\"id\"])"),
        "the update reads the given id back:\n{port}"
    );
    assert!(
        port.contains("ArchiveWidget.new(id: id)"),
        "the delete dispatches the address alone:\n{port}"
    );
    assert!(
        port.contains("NoteWidget.new(params)"),
        "the declared none dispatches the params:\n{port}"
    );
    assert!(
        port.contains("defp lookup_widget(id_or_slug) do"),
        "the id-or-slug read branches in a private helper:\n{port}"
    );
    assert!(
        port.contains("{:ok, Repo.all(ListWidgets.new(query))}"),
        "the collection names the query citizen:\n{port}"
    );
    let test_file = std::fs::read_to_string(new.join(operation_test("create_widget"))).unwrap();
    assert!(
        test_file.contains("describe \"Public API\" do"),
        "the Public API describe rides in the operation's own test file:\n{test_file}"
    );

    // pickup: running the port over the oracle-produced tree changes nothing
    let before: Vec<Vec<u8>> = written
        .iter()
        .map(|path| std::fs::read(old.join(path)).unwrap())
        .collect();
    for args in &sequence[PORTED..] {
        run_gen(binary, &old, args);
    }
    for (path, bytes) in written.iter().zip(&before) {
        assert_eq!(
            &std::fs::read(old.join(path)).unwrap(),
            bytes,
            "the port rewrote a file the oracle produced: {path}"
        );
    }

    for root in [&old, &new] {
        let _ = std::fs::remove_dir_all(root);
    }
}

// ---- wave 10: test_support --------------------------------------------------------------

/// The widget citizen's fixture projection file.
const FIXTURES_FILE: &str = "services/api/test/support/catalog/equipment/fixtures/widgets.ex";
/// The composite factory ledger the same run writes.
const FACTORY_FILE: &str = "services/api/test/support/catalog/equipment/equipment.ex";

/// Every file the `test_support` generator writes for the widget citizen
/// into a fresh copy of the fixtures repo: the fixture projection, the
/// composite factory ledger, and the read model both blueprints pull as
/// their dependency.
fn test_support_paths() -> Vec<String> {
    vec![
        READ_MODEL.to_string(),
        FACTORY_FILE.to_string(),
        FIXTURES_FILE.to_string(),
    ]
}

#[test]
fn test_support_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");
    let args = ["test_support", "widget"];

    // the oracle: formats inside its own run
    let old = sandbox("oracle");
    let (o_ok, o_report) = run_gen_out(&oracle, &old, &args);
    assert!(o_ok, "oracle run failed: {o_report}");

    // the port: splice now, format once — exactly what the mix binding does
    let new = sandbox("port");
    let (p_ok, p_report) = run_gen_out(binary, &new, &args);
    assert!(p_ok, "port run failed: {p_report}");

    // the two reports state the same run: the three Created files and the
    // read model's own unresolved rule, nothing else
    assert_eq!(
        o_report, p_report,
        "--- oracle\n{o_report}\n--- port\n{p_report}"
    );
    for path in [FIXTURES_FILE, FACTORY_FILE] {
        assert!(
            p_report.contains(&format!("  {path}")),
            "the run must state {path}:\n{p_report}"
        );
    }

    let written = test_support_paths();
    for path in &written {
        format_with_elixir(&new.join("services/api"), &new.join(path));
    }

    // every file the generator wrote matches, byte for byte
    for path in &written {
        let oracle_text = std::fs::read_to_string(old.join(path)).unwrap();
        let port_text = std::fs::read_to_string(new.join(path)).unwrap();
        assert_eq!(port_text, oracle_text, "test_support file differs: {path}");
    }

    // pickup: running the port over the oracle-produced tree changes nothing
    // and re-reports the projection as Ignored, never as a rewrite
    let before: Vec<Vec<u8>> = written
        .iter()
        .map(|path| std::fs::read(old.join(path)).unwrap())
        .collect();
    let (pickup_ok, pickup_report) = run_gen_out(binary, &old, &args);
    assert!(pickup_ok, "port pickup run failed: {pickup_report}");
    assert!(
        !pickup_report.contains("Rewritten"),
        "the projection re-renders to the standing bytes, never a rewrite:\n{pickup_report}"
    );
    for (path, bytes) in written.iter().zip(&before) {
        assert_eq!(
            &std::fs::read(old.join(path)).unwrap(),
            bytes,
            "the port rewrote a file the oracle produced: {path}"
        );
    }

    // the projection's rewrite-on-drift: a hand-edited fixture value is
    // staleness, not a missing unit — both tools report `Rewritten` for the
    // whole file and land it back on the model's bytes
    let fixtures = std::fs::read(old.join(FIXTURES_FILE)).unwrap();
    for root in [&old, &new] {
        let text = std::fs::read_to_string(root.join(FIXTURES_FILE)).unwrap();
        let edited = text.replace("title: \"Classic Widget\"", "title: \"Hand Edited\"");
        assert_ne!(edited, text, "the fixture carries the seeded title");
        std::fs::write(root.join(FIXTURES_FILE), &edited).unwrap();
    }
    let (o_ok, o_rewrite) = run_gen_out(&oracle, &old, &args);
    let (p_ok, p_rewrite) = run_gen_out(binary, &new, &args);
    assert!(o_ok && p_ok, "a rewrite is a verdict, not a failure");
    for report in [&o_rewrite, &p_rewrite] {
        assert!(
            report.lines().any(|line| line.trim() == FIXTURES_FILE),
            "the projection rewrite is stated for {FIXTURES_FILE}:\n{report}"
        );
        assert!(
            report.contains("Rewritten"),
            "both tools rewrite:\n{report}"
        );
    }
    assert_eq!(
        o_rewrite, p_rewrite,
        "--- oracle\n{o_rewrite}\n--- port\n{p_rewrite}"
    );
    let rewritten = std::fs::read(old.join(FIXTURES_FILE)).unwrap();
    assert_eq!(
        rewritten, fixtures,
        "the rewrite lands the model's bytes back"
    );
    assert_eq!(
        std::fs::read(new.join(FIXTURES_FILE)).unwrap(),
        rewritten,
        "both tools land the same bytes"
    );

    for root in [&old, &new] {
        let _ = std::fs::remove_dir_all(root);
    }
}

// ---- wave 11: view --------------------------------------------------------------

/// Every file the `view` generator (and its prerequisite run) writes for the
/// widget citizen into a fresh copy of the fixtures repo: the read model it
/// reads, the view module, and the view's own test file. Files owned by
/// unported generators are excluded here the way the earlier gates exclude
/// them: the oracle's creating runs also project the test-support fixtures
/// (wave 10) into `services/api/test/support/`, and the web router rows are
/// the oracle's notes for generators later waves port.
fn view_paths() -> Vec<String> {
    vec![
        READ_MODEL.to_string(),
        "services/api/lib/sportipedia_web/catalog/equipment/widget/widget_view.ex".to_string(),
        "services/api/test/sportipedia_web/catalog/equipment/widget/widget_view_test.exs"
            .to_string(),
    ]
}

#[test]
fn view_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");

    // The read model first — the known-good build order: the view test's
    // read-model alias gates on its file, and `view widget` is the generator
    // run this wave owns. The generator is fixed-shape, so no run carries
    // `--template`.
    let sequence: Vec<Vec<&str>> = vec![vec!["read_model", "widget"], vec!["view", "widget"]];

    // the oracle: formats inside its own run
    let old = sandbox("oracle");
    for args in &sequence {
        let (ok, out) = run_gen_out(&oracle, &old, args);
        assert!(ok, "oracle run failed: {args:?}\n{out}");
    }

    // the port: splice now, format once — exactly what the mix binding does
    let new = sandbox("port");
    for args in &sequence {
        let (ok, out) = run_gen_out(binary, &new, args);
        assert!(ok, "port run failed: {args:?}\n{out}");
    }

    let written = view_paths();
    for path in &written {
        format_with_elixir(&new.join("services/api"), &new.join(path));
    }

    // every file the generators wrote matches, byte for byte
    for path in &written {
        let oracle_text = std::fs::read_to_string(old.join(path)).unwrap();
        let port_text = std::fs::read_to_string(new.join(path)).unwrap();
        assert_eq!(port_text, oracle_text, "view file differs: {path}");
    }

    // the shape: the singular type, the pluralized path, the attributes
    // without id, and the test with the four describes and both aliases
    let view = std::fs::read_to_string(new.join(&written[1])).unwrap();
    for line in [
        "use JSONAPI.View, type: \"widget\"",
        "def path, do: \"catalog/equipment/widgets\"",
        "def fields, do: [:title, :slug, :archivedAt, :coachId, :description, :label, :teamId]",
    ] {
        assert!(view.contains(line), "the view says {line}:\n{view}");
    }
    let test_file = std::fs::read_to_string(new.join(&written[2])).unwrap();
    for subject in ["type/0", "fields/0", "path/0", "render show.json"] {
        assert!(
            test_file.contains(&format!("describe \"{subject}\" do")),
            "no describe {subject}:\n{test_file}"
        );
    }
    assert!(
        test_file.contains("use SportipediaWeb.ConnCase"),
        "the web test case is used:\n{test_file}"
    );
    assert!(
        test_file.contains("alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel"),
        "the read model alias landed once its file existed:\n{test_file}"
    );

    // pickup: running the port over the oracle-produced tree changes nothing
    let before: Vec<Vec<u8>> = written
        .iter()
        .map(|path| std::fs::read(old.join(path)).unwrap())
        .collect();
    for args in &sequence {
        let (ok, out) = run_gen_out(binary, &old, args);
        assert!(ok, "port pickup run failed: {args:?}\n{out}");
    }
    for (path, bytes) in written.iter().zip(&before) {
        assert_eq!(
            &std::fs::read(old.join(path)).unwrap(),
            bytes,
            "the port rewrote a file the oracle produced: {path}"
        );
    }

    let _ = std::fs::remove_dir_all(&old);
    let _ = std::fs::remove_dir_all(&new);
}

// ---- wave 12: schema ------------------------------------------------------------

/// Every file the `schema` generator (and its prerequisite chain) writes for
/// the widget citizen: the read model and the view it derives from, the four
/// schema roles the element kinds declare — the response pair, the create and
/// update requests, the collection query parameters — and their test files.
fn schema_paths() -> Vec<String> {
    let lib = "services/api/lib/sportipedia_web/catalog/equipment/widget/schemas";
    let test = "services/api/test/sportipedia_web/catalog/equipment/widget/schemas";
    vec![
        READ_MODEL.to_string(),
        "services/api/lib/sportipedia_web/catalog/equipment/widget/widget_view.ex".to_string(),
        "services/api/test/sportipedia_web/catalog/equipment/widget/widget_view_test.exs"
            .to_string(),
        format!("{lib}/widget_response.ex"),
        format!("{test}/widget_response_test.exs"),
        format!("{lib}/widget_collection_response.ex"),
        format!("{test}/widget_collection_response_test.exs"),
        format!("{lib}/create_widget_request.ex"),
        format!("{test}/create_widget_request_test.exs"),
        format!("{lib}/edit_widget_request.ex"),
        format!("{test}/edit_widget_request_test.exs"),
        format!("{lib}/list_widgets_query_params.ex"),
        format!("{test}/list_widgets_query_params_test.exs"),
    ]
}

#[test]
fn schema_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");

    // The known-good build order to the web actor, run in the same sequence
    // on both sides. The view precedes the schemas: every derived body and
    // view alias gates on its file. Four schema shapes: the read model's
    // response pair, the `create` request (the generated id is internal, the
    // caller-provided fields carry the model's descriptions), the `update`
    // request (the caller provides the id: it rides in the schema and its
    // requirement), and the collection query's parameters (filter, sort,
    // page derived from the model's declarations).
    let sequence: Vec<Vec<&str>> = vec![
        vec!["read_model", "widget"],
        vec!["view", "widget"],
        vec!["schema", "widget"],
        vec!["schema", "create-widget"],
        vec!["schema", "edit-widget"],
        vec!["schema", "list-widgets"],
    ];

    // the oracle: formats inside its own run
    let old = sandbox("oracle");
    for args in &sequence {
        let (ok, out) = run_gen_out(&oracle, &old, args);
        assert!(ok, "oracle run failed: {args:?}\n{out}");
    }

    // the port: splice now, format once — exactly what the mix binding does
    let new = sandbox("port");
    for args in &sequence {
        let (ok, out) = run_gen_out(binary, &new, args);
        assert!(ok, "port run failed: {args:?}\n{out}");
    }

    let written = schema_paths();
    for path in &written {
        format_with_elixir(&new.join("services/api"), &new.join(path));
    }

    // every file the generators wrote matches, byte for byte
    for path in &written {
        let oracle_text = std::fs::read_to_string(old.join(path)).unwrap();
        let port_text = std::fs::read_to_string(new.join(path)).unwrap();
        assert_eq!(port_text, oracle_text, "schema file differs: {path}");
    }

    // the shapes really are the four shapes
    let response = std::fs::read_to_string(new.join(&written[3])).unwrap();
    assert!(
        response.contains("OpenApiSchema.from_view(WidgetView, title: \"equipment.Widget\")"),
        "the response derives from the view:\n{response}"
    );
    assert!(
        response.contains("require OpenApiSpex"),
        "the require line is a unit of the plan:\n{response}"
    );
    let collection = std::fs::read_to_string(new.join(&written[5])).unwrap();
    assert!(
        collection.contains(
            "OpenApiSchema.from_view(WidgetView, title: \"equipment.Widgets\", many: true)"
        ),
        "the collection response says many and pluralizes:\n{collection}"
    );
    let create = std::fs::read_to_string(new.join(&written[7])).unwrap();
    assert!(
        create.contains("title: \"equipment.CreateWidgetRequest\""),
        "the request names the command:\n{create}"
    );
    assert!(
        create.contains("description: \"Owning coach (optional, mutually exclusive with teamId)\""),
        "the field descriptions are the model's own words:\n{create}"
    );
    assert!(
        create.contains("required: [:title, :slug]"),
        "the required pair rides along:\n{create}"
    );
    assert!(
        !create.contains("id: %OpenApiSpex.Schema"),
        "the generated (internal) id is not a request parameter:\n{create}"
    );
    let edit = std::fs::read_to_string(new.join(&written[9])).unwrap();
    assert!(
        edit.contains("id: %OpenApiSpex.Schema{type: :string, description: \"Unique identifier\"}"),
        "the caller-provided id addresses the existing widget:\n{edit}"
    );
    assert!(
        edit.contains("required: [:id]"),
        "and it is required:\n{edit}"
    );
    let params = std::fs::read_to_string(new.join(&written[11])).unwrap();
    assert!(
        params.contains("OpenApiSchema.query_params(WidgetView,"),
        "the parameters derive from the view:\n{params}"
    );
    assert!(
        params.contains("filter: [title: \"Filter widgets by title (partial match)\"]"),
        "the filter description is the model's own:\n{params}"
    );
    assert!(
        params.contains("sort: ~w(title slug)"),
        "the declared sortable fields ride along:\n{params}"
    );
    assert!(
        params.contains("page: :numbered"),
        "the bare page parameter is the house style:\n{params}"
    );
    for (short, i) in [
        ("WidgetResponse", 3usize),
        ("WidgetCollectionResponse", 5),
        ("CreateWidgetRequest", 7),
        ("EditWidgetRequest", 9),
        ("ListWidgetsQueryParams", 11),
    ] {
        let module = format!("SportipediaWeb.Catalog.Equipment.Widget.Schemas.{short}");
        let file = std::fs::read_to_string(new.join(&written[i])).unwrap();
        assert!(
            file.contains(&format!("defmodule {module} do")),
            "the schema module is {module}:\n{file}"
        );
        let test_file = std::fs::read_to_string(new.join(&written[i + 1])).unwrap();
        assert!(
            test_file.contains(&format!("describe \"{short}\" do")),
            "the paired test asserts on {short}:\n{test_file}"
        );
        assert!(
            test_file.contains(&format!("alias {module}")),
            "and aliases it:\n{test_file}"
        );
    }

    // pickup: running the port over the oracle-produced tree changes nothing
    let before: Vec<Vec<u8>> = written
        .iter()
        .map(|path| std::fs::read(old.join(path)).unwrap())
        .collect();
    for args in &sequence {
        let (ok, out) = run_gen_out(binary, &old, args);
        assert!(ok, "port pickup run failed: {args:?}\n{out}");
    }
    for (path, bytes) in written.iter().zip(&before) {
        assert_eq!(
            &std::fs::read(old.join(path)).unwrap(),
            bytes,
            "the port rewrote a file the oracle produced: {path}"
        );
    }

    let _ = std::fs::remove_dir_all(&old);
    let _ = std::fs::remove_dir_all(&new);
}

// ---- wave 13: controller ------------------------------------------------------------

/// Every file the `controller` generator writes for the widget citizen: the
/// one controller module every operation shares, the web router the endpoint
/// routes register in, and one endpoint test file per operation. Files the
/// prerequisite chain owns — the read model, the view, the schemas, the
/// fixture projection — are excluded the way the earlier gates exclude files
/// of later waves.
fn controller_paths() -> Vec<String> {
    let web = "services/api/test/sportipedia_web/catalog/equipment/widget/operations";
    vec![
        "services/api/lib/sportipedia_web/catalog/equipment/widget/widget_controller.ex"
            .to_string(),
        "services/api/lib/sportipedia_web/router.ex".to_string(),
        format!("{web}/create_widget_endpoint_test.exs"),
        format!("{web}/edit_widget_endpoint_test.exs"),
        format!("{web}/archive_widget_endpoint_test.exs"),
        format!("{web}/note_widget_endpoint_test.exs"),
        format!("{web}/relabel_widget_endpoint_test.exs"),
        format!("{web}/read_widget_endpoint_test.exs"),
        format!("{web}/list_widgets_endpoint_test.exs"),
    ]
}

#[test]
fn controller_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");

    // The known-good build order up to the web actor, run in the same
    // sequence on both sides. The action gates on the public API, a single
    // read also on the read model, and every reference alias on the view,
    // schema or read model citizen it names; the endpoint test seeds reads
    // through the fixture factory, so `test_support` runs first. Seven
    // controller runs cover the five command shapes (create, update, delete,
    // none) and both query shapes (read, collection).
    let operations = [
        "create-widget",
        "edit-widget",
        "archive-widget",
        "note-widget",
        "relabel-widget",
        "read-widget",
        "list-widgets",
    ];
    let mut sequence: Vec<Vec<&str>> = vec![
        vec!["read_model", "widget"],
        vec!["test_support", "widget"],
        vec!["query", "read-widget"],
        vec!["query", "list-widgets"],
        vec!["internal_api", "aggregate.widget"],
    ];
    for kebab in &operations[..5] {
        sequence.push(vec!["command", kebab]);
    }
    for kebab in &operations[..5] {
        sequence.push(vec!["policy", kebab]);
    }
    for kebab in &operations {
        sequence.push(vec!["public_api", kebab]);
    }
    sequence.push(vec!["view", "widget"]);
    sequence.push(vec!["schema", "widget"]);
    for kebab in [
        "create-widget",
        "edit-widget",
        "note-widget",
        "relabel-widget",
        "list-widgets",
    ] {
        sequence.push(vec!["schema", kebab]);
    }
    const PREREQUISITES: usize = 29;
    for kebab in &operations {
        sequence.push(vec!["controller", kebab]);
    }

    // the oracle: formats inside its own run
    let old = sandbox("oracle");
    for args in &sequence {
        let (ok, out) = run_gen_out(&oracle, &old, args);
        assert!(ok, "oracle run failed: {args:?}\n{out}");
    }

    // the port: splice now, format once — exactly what the mix binding does
    let new = sandbox("port");
    for args in &sequence {
        let (ok, out) = run_gen_out(binary, &new, args);
        assert!(ok, "port run failed: {args:?}\n{out}");
    }

    let written = controller_paths();
    for path in &written {
        format_with_elixir(&new.join("services/api"), &new.join(path));
    }

    // every file the generators wrote matches, byte for byte
    for path in &written {
        let oracle_text = std::fs::read_to_string(old.join(path)).unwrap();
        let port_text = std::fs::read_to_string(new.join(path)).unwrap();
        assert_eq!(port_text, oracle_text, "controller file differs: {path}");
    }

    // the shapes: the shared module carries one contract block and one
    // action per operation, the policy plug and the list parser above them
    let controller = std::fs::read_to_string(new.join(&written[0])).unwrap();
    for line in [
        "use SportipediaWeb, :controller",
        "use OpenApiSpex.ControllerSpecs",
        "plug Bodyguard.Plug.Authorize,",
        "policy: Sportipedia.Catalog.Equipment.Widget.Policy,",
        "plug JSONAPI.QueryParser,",
        "filter: ~w(title),",
        "tags [\"equipment\"]",
        "alias SportipediaWeb.System.FallbackController",
    ] {
        assert!(
            controller.contains(line),
            "the controller says {line}:\n{controller}"
        );
    }
    for op in [
        "create_widget",
        "edit_widget",
        "archive_widget",
        "note_widget",
        "relabel_widget",
        "read_widget",
        "list_widgets",
    ] {
        assert!(
            controller.contains(&format!("operation :{op},"))
                && controller.contains(&format!("def {op}(conn, _) do")),
            "no contract and action for {op}:\n{controller}"
        );
    }
    assert!(
        controller.contains("no_content: \"The widget was processed without materialization\""),
        "the declared none answers without a body:\n{controller}"
    );
    assert!(
        controller.contains(
            "request_body: {\"The widget attributes\", \"application/json\", EditWidgetRequest}"
        ),
        "the update names its request schema:\n{controller}"
    );
    assert!(
        controller.contains("id_or_slug: [in: :path"),
        "the read documents its path parameter:\n{controller}"
    );
    assert!(
        controller.contains("{:ok, %WidgetReadModel{} = widget} ->"),
        "the read matches the read model struct:\n{controller}"
    );
    assert!(
        controller.contains("case Widget.list_widgets(conn.assigns.jsonapi_query) do"),
        "the collection runs the parsed query:\n{controller}"
    );

    // the router registers each endpoint in its scope chain, and the missing
    // `/widgets` level materializes inside the existing `/equipment` scope
    let router = std::fs::read_to_string(new.join(&written[1])).unwrap();
    assert!(
        router.contains("scope \"/widgets\", Widget do"),
        "the scope level is materialized:\n{router}"
    );
    for line in [
        "post \"/create-widget\", WidgetController, :create_widget",
        "post \"/archive-widget\", WidgetController, :archive_widget",
        "get \"/\", WidgetController, :list_widgets",
        "get \"/:id_or_slug\", WidgetController, :read_widget",
    ] {
        assert!(router.contains(line), "no route line {line}:\n{router}");
    }
    assert!(
        router.contains("post \"/create-gadget\", GadgetController, :create_gadget"),
        "the hand-written gadget scope survives:\n{router}"
    );

    // the endpoint tests: one file per operation with the status matrix, and
    // the seed the shape needs
    let create = std::fs::read_to_string(new.join(&written[2])).unwrap();
    assert!(
        create.contains("describe \"POST /catalog/equipment/widgets/create-widget\" do"),
        "{create}"
    );
    assert!(
        create.contains("jsonapi_body(\"widget\", %{label: \"Pommel\", slug: \"pommel-horse\", title: \"Pommel Horse\"})"),
        "the write body is the feature scenario's data:\n{create}"
    );
    assert!(
        create.contains("assert json_response(conn, 403)"),
        "{create}"
    );
    let edit = std::fs::read_to_string(new.join(&written[3])).unwrap();
    assert!(
        edit.contains("/catalog/equipment/widgets/create-widget"),
        "the update creates the row it edits:\n{edit}"
    );
    assert!(edit.contains("assert jsonapi_id(body) == id"), "{edit}");
    let archive = std::fs::read_to_string(new.join(&written[4])).unwrap();
    assert!(
        archive.contains("Widget.create_widget(%{"),
        "the delete seeds through the create command:\n{archive}"
    );
    assert!(archive.contains("assert conn.status == 204"), "{archive}");
    let note = std::fs::read_to_string(new.join(&written[5])).unwrap();
    assert!(
        note.contains("jsonapi_body(\"widget\", %{comment: \"sample-comment\"})"),
        "{note}"
    );
    let read = std::fs::read_to_string(new.join(&written[7])).unwrap();
    assert!(
        read.contains("describe \"GET /catalog/equipment/widgets/:id_or_slug (read-widget)\" do"),
        "{read}"
    );
    assert!(
        read.contains("Equipment.new_widget(WidgetFixtures.classic_widget())"),
        "the read seeds its row through the fixture factory:\n{read}"
    );
    assert!(
        read.contains("alias Sportipedia.TestSupport.Catalog.Equipment.WidgetFixtures"),
        "{read}"
    );
    let list = std::fs::read_to_string(new.join(&written[8])).unwrap();
    assert!(
        list.contains("Equipment.new_widgets(WidgetFixtures.widgets())"),
        "the collection seeds every example:\n{list}"
    );

    // pickup: running the port over the oracle-produced tree changes nothing
    let before: Vec<Vec<u8>> = written
        .iter()
        .map(|path| std::fs::read(old.join(path)).unwrap())
        .collect();
    for args in &sequence[PREREQUISITES..] {
        let (ok, out) = run_gen_out(binary, &old, args);
        assert!(ok, "port pickup run failed: {args:?}\n{out}");
    }
    for (path, bytes) in written.iter().zip(&before) {
        assert_eq!(
            &std::fs::read(old.join(path)).unwrap(),
            bytes,
            "the port rewrote a file the oracle produced: {path}"
        );
    }

    let _ = std::fs::remove_dir_all(&old);
    let _ = std::fs::remove_dir_all(&new);
}

// ---- wave 14: bruno ---------------------------------------------------------------

/// Every file the `bruno` generator writes in this gate: the request
/// documents and the constituent folder for the widget, and the same pair for
/// the position constituent of another composite.
fn bruno_paths() -> Vec<String> {
    let widget = "bruno/Catalog/Equipment/Widget";
    vec![
        format!("{widget}/folder.yml"),
        format!("{widget}/Create Widget.yml"),
        format!("{widget}/Read Widget.yml"),
        format!("{widget}/List Widgets.yml"),
        format!("{widget}/Edit Widget.yml"),
        "bruno/Catalog/Athlete/Position/folder.yml".to_string(),
        "bruno/Catalog/Athlete/Position/Catalog Position.yml".to_string(),
    ]
}

/// The one line a Bruno document orders itself by.
fn bruno_seq(root: &Path, path: &str) -> String {
    std::fs::read_to_string(root.join(path))
        .unwrap()
        .lines()
        .find(|line| line.starts_with("  seq: "))
        .unwrap_or("")
        .to_string()
}

#[test]
fn bruno_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");

    // Docs artifacts need no citizen around them: the request documents are
    // rendered from the model alone, so the run order is the only shared
    // state. Four widget operations in one constituent land in one folder and
    // number themselves in arrival order, and the position run opens a folder
    // tree of its own composite.
    let sequence: Vec<Vec<&str>> = vec![
        vec!["bruno", "create-widget"],
        vec!["bruno", "read-widget"],
        vec!["bruno", "list-widgets"],
        vec!["bruno", "edit-widget"],
        vec!["bruno", "catalog-position"],
    ];

    // the oracle: YAML is written verbatim, never formatted, never rewritten
    let old = sandbox("oracle");
    for args in &sequence {
        let (ok, out) = run_gen_out(&oracle, &old, args);
        assert!(ok, "oracle run failed: {args:?}\n{out}");
    }

    // the port: the same bytes, and no formatter pass at all
    let new = sandbox("port");
    for args in &sequence {
        let (ok, out) = run_gen_out(binary, &new, args);
        assert!(ok, "port run failed: {args:?}\n{out}");
    }

    let written = bruno_paths();
    for path in &written {
        let oracle_text = std::fs::read_to_string(old.join(path)).unwrap();
        let port_text = std::fs::read_to_string(new.join(path)).unwrap();
        assert_eq!(port_text, oracle_text, "bruno file differs: {path}");
    }
    for path in &written {
        assert_eq!(
            bruno_seq(&new, path),
            bruno_seq(&old, path),
            "the folder order differs: {path}"
        );
    }
    assert_eq!(
        bruno_seq(&new, &written[0]),
        "  seq: 1",
        "the first folder in its composite"
    );
    assert_eq!(
        bruno_seq(&new, &written[1]),
        "  seq: 1",
        "the first request in the folder"
    );
    assert_eq!(
        bruno_seq(&new, &written[4]),
        "  seq: 4",
        "each later request counts its siblings"
    );

    // the shapes: the verb rule, the templated URL, the JSON:API body from
    // the model's data, and the examples the feature scenarios name
    let create = std::fs::read_to_string(new.join(&written[1])).unwrap();
    assert!(create.contains("  method: POST"), "{create}");
    assert!(
        create.contains("  url: \"{{apiUrl}}/catalog/equipment/widgets/create-widget\""),
        "the URL rides on the collection variable:\n{create}"
    );
    assert!(
        create.contains("      \"title\": \"Pommel Horse\","),
        "the attributes are the scenario data:\n{create}"
    );
    assert!(
        !create.contains("\"id\":"),
        "a create body carries no id:\n{create}"
    );
    assert!(
        create.contains("  - name: Create Pommel Horse"),
        "the example is named from the scenario:\n{create}"
    );
    let folder = std::fs::read_to_string(new.join(&written[0])).unwrap();
    assert_eq!(
        folder,
        "info:\n  name: Widget\n  type: folder\n  seq: 1\n\nrequest:\n  auth: inherit\n"
    );
    let read = std::fs::read_to_string(new.join(&written[2])).unwrap();
    assert!(read.contains("  method: GET"), "{read}");
    assert!(
        read.contains("  params:\n    - name: id_or_slug\n      value: d290f1ee-6c54-4b01-90e6-d701748f0851\n      type: path"),
        "a read documents its path parameter:\n{read}"
    );
    assert!(
        read.contains("      url: \"{{apiUrl}}/catalog/equipment/widgets/d290f1ee-6c54-4b01-90e6-d701748f0851\""),
        "the example fills the parameter:\n{read}"
    );
    let list = std::fs::read_to_string(new.join(&written[3])).unwrap();
    assert!(
        !list.contains("  params:") && !list.contains("  body:"),
        "a collection documents neither:\n{list}"
    );
    let edit = std::fs::read_to_string(new.join(&written[4])).unwrap();
    assert!(
        edit.contains("    \"id\": \"{{ generated }}\","),
        "an update addresses the row by id:\n{edit}"
    );
    let position = std::fs::read_to_string(new.join(&written[6])).unwrap();
    assert!(
        position.contains("  url: \"{{apiUrl}}/catalog/athlete/positions/catalog-position\""),
        "another constituent's folder holds another route:\n{position}"
    );

    // pickup: docs artifacts are create-only, so a second run rewrites
    // nothing — not even the files this wave owns
    let before: Vec<Vec<u8>> = written
        .iter()
        .map(|path| std::fs::read(old.join(path)).unwrap())
        .collect();
    for args in &sequence {
        let (ok, out) = run_gen_out(binary, &old, args);
        assert!(ok, "port pickup run failed: {args:?}\n{out}");
    }
    for (path, bytes) in written.iter().zip(&before) {
        assert_eq!(
            &std::fs::read(old.join(path)).unwrap(),
            bytes,
            "the port rewrote a file the oracle produced: {path}"
        );
    }

    let _ = std::fs::remove_dir_all(&old);
    let _ = std::fs::remove_dir_all(&new);
}

const WIDGET: &str = "widget";

fn fixtures_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../fixtures")
        .canonicalize()
        .unwrap()
}

fn collect_files(root: &Path, dir: &Path, out: &mut Vec<(String, Vec<u8>)>) {
    for entry in std::fs::read_dir(dir).unwrap() {
        let entry = entry.unwrap();
        let path = entry.path();
        if path.is_dir() {
            collect_files(root, &path, out);
        } else {
            out.push((
                path.strip_prefix(root)
                    .unwrap()
                    .to_string_lossy()
                    .to_string(),
                std::fs::read(&path).unwrap(),
            ));
        }
    }
}

fn tree(root: &Path) -> Vec<(String, Vec<u8>)> {
    let mut files = Vec::new();
    collect_files(root, root, &mut files);
    files.sort();
    files
}

fn changed(base: &[(String, Vec<u8>)], after: &[(String, Vec<u8>)]) -> Vec<String> {
    let mut paths: Vec<String> = Vec::new();
    for (path, bytes) in after {
        match base.iter().find(|(seeded, _)| seeded == path) {
            None => paths.push(path.clone()),
            Some((_, seeded)) if seeded != bytes => paths.push(path.clone()),
            _ => {}
        }
    }
    for (path, _) in base {
        if !after.iter().any(|(seeded, _)| seeded == path) {
            paths.push(path.clone());
        }
    }
    paths.sort();
    paths.dedup();
    paths
}

fn feature_runs() -> Vec<(String, String)> {
    let model = sparch_model::Model::load(&fixtures_root().join("domain-model"));
    let input =
        sparch_elixir::suites::resolve_input(&model, sparch_elixir::suites::Suite::Feature, WIDGET)
            .expect("the widget constituent");
    sparch_elixir::suites::plan(&model, sparch_elixir::suites::Suite::Feature, &input)
        .expect("the feature suite plan")
        .into_iter()
        .map(|member| (member.generator.to_string(), member.element.address.clone()))
        .collect()
}

fn citizen_paths() -> Vec<String> {
    let mut paths = vec![
        READ_MODEL.to_string(),
        FIXTURES_FILE.to_string(),
        FACTORY_FILE.to_string(),
    ];
    for snake in [
        "widget_archived",
        "widget_created",
        "widget_edited",
        "widget_noted",
        "widget_relabelled",
        "widget_rename_logged",
    ] {
        paths.push(format!(
            "services/api/lib/sportipedia/catalog/equipment/widget/events/{snake}.ex"
        ));
        paths.push(format!(
            "services/api/test/sportipedia/catalog/equipment/widget/events/{snake}_test.exs"
        ));
    }
    paths.push("services/api/lib/sportipedia/catalog/equipment/widget/aggregate.ex".to_string());
    paths.push(query_module("read_widget"));
    paths.push(query_module("list_widgets"));
    paths.push(INTERNAL_API.to_string());
    paths.push(LOOKUP_QUERY.to_string());
    for snake in [
        "archive_widget",
        "create_widget",
        "edit_widget",
        "note_widget",
        "relabel_widget",
    ] {
        paths.push(command_module(snake));
        paths.push(handler_module(snake));
        paths.push(operation_test(snake));
    }
    for snake in ["at_most_one_owner", "unique_slug", "widget_exists"] {
        paths.push(format!(
            "services/api/lib/sportipedia/catalog/equipment/widget/validators/{snake}.ex"
        ));
    }
    paths.push(COMPOSITE_ROUTER.to_string());
    paths.push("services/api/lib/sportipedia/catalog/application.ex".to_string());
    paths.push(projector_module());
    paths.push(SUPERVISOR.to_string());
    paths.push(POLICY.to_string());
    paths.push(PUBLIC_API.to_string());
    paths.push(
        "services/api/lib/sportipedia_web/catalog/equipment/widget/widget_view.ex".to_string(),
    );
    paths.push(
        "services/api/test/sportipedia_web/catalog/equipment/widget/widget_view_test.exs"
            .to_string(),
    );
    for schema in [
        "create_widget_request.ex",
        "edit_widget_request.ex",
        "list_widgets_query_params.ex",
        "note_widget_request.ex",
        "relabel_widget_request.ex",
    ] {
        paths.push(format!(
            "services/api/lib/sportipedia_web/catalog/equipment/widget/schemas/{schema}"
        ));
    }
    paths.push(
        "services/api/lib/sportipedia_web/catalog/equipment/widget/widget_controller.ex"
            .to_string(),
    );
    paths.push("services/api/lib/sportipedia_web/router.ex".to_string());
    paths.push("bruno/Catalog/Equipment/Widget/folder.yml".to_string());
    for document in [
        "Archive Widget.yml",
        "Create Widget.yml",
        "Edit Widget.yml",
        "List Widgets.yml",
        "Note Widget.yml",
        "Read Widget.yml",
        "Relabel Widget.yml",
    ] {
        paths.push(format!("bruno/Catalog/Equipment/Widget/{document}"));
    }
    paths
}

#[test]
fn feature_parity_with_the_elixir_oracle() {
    let Some(oracle) = oracle() else {
        eprintln!("skipped: set SPARCH_ORACLE to a built tools/spgen escript");
        return;
    };
    let binary = env!("CARGO_BIN_EXE_sparch-elixir");
    let sequence = feature_runs();
    assert!(
        sequence.len() > 40,
        "the feature suite is the whole constituent: {} runs",
        sequence.len()
    );

    let old = sandbox("feature-oracle");
    for (generator, address) in &sequence {
        let (ok, out) = run_gen_out(&oracle, &old, &[generator.as_str(), address.as_str()]);
        assert!(ok, "oracle run failed: {generator} {address}\n{out}");
    }

    let new = sandbox("feature-port");
    let (port_ok, port_out) = run_gen_out(binary, &new, &["feature", WIDGET]);
    assert!(port_ok, "port feature run failed: {port_out}");

    let base = sandbox("feature-base");
    let mut written = changed(&tree(&base), &tree(&old));
    written.extend(changed(&tree(&base), &tree(&new)));
    written.sort();
    written.dedup();

    for path in &written {
        let oracle_file = old.join(path);
        let port_file = new.join(path);
        assert!(
            oracle_file.exists(),
            "the port wrote {path}, the oracle never did"
        );
        assert!(
            port_file.exists(),
            "the oracle wrote {path}, the port never did"
        );
        if path.starts_with("services/api/") && (path.ends_with(".ex") || path.ends_with(".exs")) {
            format_with_elixir(&new.join("services/api"), &port_file);
        }
        let oracle_bytes = std::fs::read(&oracle_file).unwrap();
        let port_bytes = std::fs::read(&port_file).unwrap();
        assert!(
            port_bytes == oracle_bytes,
            "feature file differs: {path}\n--- oracle\n{}\n--- port\n{}",
            String::from_utf8_lossy(&oracle_bytes),
            String::from_utf8_lossy(&port_bytes)
        );
    }

    for path in citizen_paths() {
        assert!(
            written.contains(&path),
            "the full citizen never landed {path}"
        );
    }

    let before = tree(&old);
    let (pickup_ok, pickup_out) = run_gen_out(binary, &old, &["feature", WIDGET]);
    assert!(pickup_ok, "port pickup run failed: {pickup_out}");
    let after = tree(&old);
    assert_eq!(
        after.len(),
        before.len(),
        "the pickup run changed the file set:\nport report\n{pickup_out}"
    );
    for (path, bytes) in &before {
        match after.iter().find(|(seeded, _)| seeded == path) {
            None => panic!("the port removed a file the oracle produced: {path}"),
            Some((_, now)) => assert!(
                now == bytes,
                "the port rewrote a file the oracle produced: {path}"
            ),
        }
    }

    for root in [&old, &new, &base] {
        let _ = std::fs::remove_dir_all(root);
    }
}
