//! Embeds `man/blueprints` (two directories up: crates/sparch -> ../man)
//! into the binary: the manual is part of the tool, and iterating on it
//! is "edit markdown, rebuild".

use std::{
    env, fs,
    io::Write,
    path::{Path, PathBuf},
};

fn collect(dir: &Path, prefix: &str, out: &mut Vec<(String, PathBuf)>) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    let mut dirs = Vec::new();
    for entry in entries.filter_map(Result::ok) {
        let path = entry.path();
        let name = entry.file_name().to_string_lossy().to_string();
        if path.is_dir() {
            dirs.push((name, path));
        } else if name.ends_with(".md") {
            let rel = if prefix.is_empty() {
                name
            } else {
                format!("{prefix}/{name}")
            };
            out.push((rel, path));
        }
    }
    dirs.sort();
    for (name, path) in dirs {
        let sub = if prefix.is_empty() {
            name
        } else {
            format!("{prefix}/{name}")
        };
        collect(&path, &sub, out);
    }
}

fn main() {
    let manifest = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let man = manifest.join("../../man/blueprints");
    println!(
        "cargo:rerun-if-changed={}",
        man.canonicalize().unwrap_or(man.clone()).display()
    );

    let mut pages = Vec::new();
    collect(&man, "", &mut pages);
    pages.sort();

    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let mut file = fs::File::create(out_dir.join("pages.rs")).unwrap();
    writeln!(
        &mut file,
        "/// (relative page path, embedded content) in sorted order."
    )
    .unwrap();
    writeln!(&mut file, "pub const PAGES: &[(&str, &str)] = &[").unwrap();
    for (rel, path) in pages {
        writeln!(
            &mut file,
            "    ({:?}, include_str!({:?})),",
            rel,
            path.canonicalize().unwrap_or(path)
        )
        .unwrap();
    }
    writeln!(&mut file, "];").unwrap();
}
