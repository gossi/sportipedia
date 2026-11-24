//! Shared acceptance helpers: the fixture sandbox, the CLI runner, and the
//! tree-diff that isolates what a run created. Used by both `acceptance.rs`
//! (behavior) and `expected_output.rs` (this-model-in, these-files-out).
#![allow(dead_code)] // each binary uses a subset; the module is shared

use std::collections::BTreeSet;
use std::path::{Path, PathBuf};
use std::process::Command;

/// The shared fixture corpus (model + host repo), used by every BE test.
pub fn fixtures() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../fixtures")
        .canonicalize()
        .expect("shared fixture corpus")
}

/// Where committed expected files live, mirroring the repo layout under a
/// per-scenario directory: `tests/expected/<scenario>/services/api/...`.
pub fn expected_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("tests/expected")
        .canonicalize()
        .unwrap_or_else(|_| {
            let fresh = Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/expected");
            std::fs::create_dir_all(&fresh).expect("create the expected corpus dir");
            fresh
        })
}

/// A fresh copy of the fixture repository: hosts in place, model mounted
/// at `docs/domain-model`, no generated citizen yet.
pub fn sandbox(tag: &str) -> PathBuf {
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

pub fn copy_tree(from: &Path, to: &Path) {
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

/// Run the real compiled CLI over a sandbox root; returns exit code plus
/// merged stdout/stderr.
pub fn sparch(root: &Path, args: &[&str]) -> (i32, String) {
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

/// Every tracked-output file under the sandbox, as repo-relative paths. The
/// corpus mount (`docs/`) and build leftovers are excluded — only generated
/// source trees are of interest.
pub fn output_files(root: &Path) -> BTreeSet<String> {
    let mut files = BTreeSet::new();
    for base in ["services", "bruno"] {
        collect(&root.join(base), root, &mut files);
    }
    files
}

fn collect(dir: &Path, root: &Path, files: &mut BTreeSet<String>) {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return;
    };
    for entry in entries.filter_map(Result::ok) {
        let path = entry.path();
        if path.is_dir() {
            collect(&path, root, files);
        } else if let Ok(rel) = path.strip_prefix(root) {
            files.insert(rel.to_string_lossy().replace('\\', "/"));
        }
    }
}

/// Files present after the run that were not there before — exactly the set
/// the generator created (a modified human host is not "created").
pub fn created(before: &BTreeSet<String>, after: &BTreeSet<String>) -> Vec<String> {
    after.difference(before).cloned().collect()
}

/// Read a repo-relative file from a sandbox.
pub fn read(root: &Path, rel: &str) -> String {
    std::fs::read_to_string(root.join(rel)).unwrap_or_else(|e| panic!("cannot read {rel}: {e}"))
}

pub fn cleanup(root: &Path) {
    let _ = std::fs::remove_dir_all(root);
}

/// Refreshing the corpus is explicit and off by default: only
/// `SPARCH_UPDATE_EXPECTED=1` writes it. CI never sets it, so a run there
/// only asserts.
pub fn update_requested() -> bool {
    matches!(
        std::env::var("SPARCH_UPDATE_EXPECTED").as_deref(),
        Ok("1") | Ok("true")
    )
}
