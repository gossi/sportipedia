//! Parity of `spgen validate` against the Elixir `SpGen.Check` engine,
//! opt-in: `SPGEN_VALIDATE_MIX=1` and a sibling `tools/spgen` with compiled
//! deps. The comparison is the finding lines themselves — file, element
//! address, message — in sorted order. The fixture corpus is the arena.

use std::path::{Path, PathBuf};
use std::process::Command;

fn repo() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../../../")
        .canonicalize()
        .unwrap()
}

fn sandbox() -> PathBuf {
    let fixtures = repo().join("tools/spgen-rs/fixtures");
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let root = std::env::temp_dir().join(format!("spgen-validate-parity-{unique}"));
    copy(&fixtures.join("repo"), &root);
    std::fs::create_dir_all(root.join("docs")).unwrap();
    copy(
        &fixtures.join("domain-model"),
        &root.join("docs/domain-model"),
    );
    root
}

fn copy(from: &Path, to: &Path) {
    std::fs::create_dir_all(to).unwrap();
    for entry in std::fs::read_dir(from).unwrap() {
        let entry = entry.unwrap();
        let target = to.join(entry.file_name());
        if entry.file_type().unwrap().is_dir() {
            copy(&entry.path(), &target);
        } else {
            std::fs::copy(entry.path(), &target).unwrap();
        }
    }
}

#[test]
fn findings_match_the_elixir_check_engine() {
    if std::env::var("SPGEN_VALIDATE_MIX").is_err() {
        eprintln!("skipped: set SPGEN_VALIDATE_MIX=1 to compare against the Elixir engine");
        return;
    }
    let root = sandbox();
    let root_text = root.display().to_string();

    // the Elixir oracle: SpGen.Check.run over the same tree
    let script = r##"{:ok, f} = SpGen.Check.run(["--root", System.get_env("SPGEN_VALIDATE_ROOT")]);
Enum.each(f, fn x -> IO.puts("#{x.file}: #{x.element}: #{x.message}") end)"##;
    let oracle = Command::new("mix")
        .args(["run", "--no-start", "-e", script])
        .current_dir(repo().join("tools/spgen"))
        .env("SPGEN_VALIDATE_ROOT", &root_text)
        .env("MIX_ENV", "dev")
        .output()
        .expect("run SpGen.Check");
    assert!(oracle.status.success(), "elixir check failed");
    let mut expected: Vec<String> = String::from_utf8_lossy(&oracle.stdout)
        .lines()
        .map(str::to_string)
        .collect();
    expected.sort();

    // the Rust engine, in-process
    let report = spgen::validate::run(&spgen::validate::Options {
        targets: Vec::new(),
        repo_root: Some(root.clone()),
        model: None,
        cwd: root.clone(),
    })
    .expect("rust validate runs");
    let mut actual: Vec<String> = report
        .findings
        .iter()
        .map(|f| format!("{}: {}: {}", f.file, f.element, f.message))
        .collect();
    actual.sort();

    assert!(
        !expected.is_empty(),
        "the fixture corpus must carry findings for this test to mean anything"
    );
    assert_eq!(
        actual, expected,
        "validate findings must equal SpGen.Check's"
    );
    let _ = std::fs::remove_dir_all(&root);
}
