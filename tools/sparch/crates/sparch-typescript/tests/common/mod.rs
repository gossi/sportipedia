//! Shared acceptance helpers for the FE binary: the fixture sandbox, the
//! CLI runner, the tree diff that isolates what a run created, and the
//! oxc parse guard. Used by `acceptance.rs` (behavior) and
//! `expected_files.rs` (this-model-in, this-file-out).
#![allow(dead_code)] // each binary uses a subset; the module is shared

use std::path::{Path, PathBuf};
use std::process::Command;

use oxc_allocator::Allocator;
use oxc_parser::Parser;
use oxc_span::SourceType;

/// The shared fixture corpus (the model), mounted at the repo location by
/// every sandbox.
pub fn corpus() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../fixtures/domain-model")
        .canonicalize()
        .expect("fixture corpus")
}

/// Where committed expected files live, as flat pattern names:
/// `tests/expected/<category>/<name>.ts`.
pub fn expected_root() -> PathBuf {
    let fresh = Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/expected");
    std::fs::create_dir_all(&fresh).expect("create the expected corpus dir");
    fresh
}

/// A fresh sandbox: the model at `docs/domain-model`, the registration
/// hosts the generator must not invent, and no generated citizen yet.
pub fn sandbox(tag: &str) -> PathBuf {
    static SEQ: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
    let unique = format!(
        "{}-{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos(),
        SEQ.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
    );
    let dir = std::env::temp_dir().join(format!("sparch-ts-{tag}-{unique}"));
    std::fs::create_dir_all(dir.join("docs")).unwrap();
    copy_dir(&corpus(), &dir.join("docs/domain-model"));
    std::fs::create_dir_all(dir.join("apps/catalog/src")).unwrap();
    std::fs::write(
        dir.join("apps/catalog/src/config.ts"),
        "import type { ApplicationInstance } from '@ember/application/instance';\n\
         import type { Store } from '#support/data';\n\n\
         function configureApi(app: ApplicationInstance) {\n\
         \x20 const store = app.lookup('service:store') as Store;\n\n\
         \x20 return store;\n\
         }\n\n\
         export function configure(app: ApplicationInstance) {\n\
         \x20 configureApi(app);\n\
         }\n",
    )
    .unwrap();
    let user = dir.join("apps/catalog/tests/user/support/fixtures");
    std::fs::create_dir_all(&user).unwrap();
    std::fs::write(
        user.join("index.ts"),
        "export const ADMIN = 'admin' as const;\n\
         export const GUEST = 'guest' as const;\n\
         export const USER = 'user' as const;\n",
    )
    .unwrap();
    dir
}

pub fn copy_dir(from: &Path, to: &Path) {
    std::fs::create_dir_all(to).unwrap();
    for entry in std::fs::read_dir(from).unwrap() {
        let entry = entry.unwrap();
        let target = to.join(entry.file_name());
        if entry.file_type().unwrap().is_dir() {
            copy_dir(&entry.path(), &target);
        } else {
            std::fs::copy(entry.path(), &target).unwrap();
        }
    }
}

/// Run the real compiled CLI over a sandbox root; returns exit code plus
/// merged stdout/stderr.
pub fn sparch(root: &Path, args: &[&str]) -> (i32, String) {
    let binary = env!("CARGO_BIN_EXE_sparch-typescript");
    let output = Command::new(binary)
        .args(args)
        .arg("--repo-root")
        .arg(root)
        .output()
        .expect("run sparch-typescript");
    let mut text = String::from_utf8_lossy(&output.stdout).to_string();
    text.push_str(&String::from_utf8_lossy(&output.stderr));
    (output.status.code().unwrap_or(-1), text)
}

/// Every app-tree file under the sandbox, repo-relative. The corpus mount
/// is not part of this space (it lives under docs/).
pub fn output_files(root: &Path) -> std::collections::BTreeSet<String> {
    let mut files = std::collections::BTreeSet::new();
    collect(&root.join("apps"), root, &mut files);
    files
}

fn collect(dir: &Path, root: &Path, files: &mut std::collections::BTreeSet<String>) {
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

pub fn read(root: &Path, rel: &str) -> String {
    std::fs::read_to_string(root.join(rel)).unwrap_or_else(|e| panic!("cannot read {rel}: {e}"))
}

pub fn cleanup(root: &Path) {
    let _ = std::fs::remove_dir_all(root);
}

/// Whether one generated TypeScript file parses without diagnostics.
/// Returns `None` for success, the diagnostics text otherwise.
pub fn parse_problems(rel: &str, text: &str) -> Option<String> {
    let path = Path::new(rel);
    let allocator = Allocator::default();
    let source_type = SourceType::from_path(path).unwrap_or_else(|_| SourceType::ts());
    let ret = Parser::new(&allocator, text, source_type).parse();
    if ret.fatal_error || !ret.diagnostics.is_empty() {
        let notes: Vec<String> = ret.diagnostics.iter().map(|d| d.to_string()).collect();
        return Some(if notes.is_empty() {
            "fatal parse error".to_string()
        } else {
            notes.join("; ")
        });
    }
    None
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
