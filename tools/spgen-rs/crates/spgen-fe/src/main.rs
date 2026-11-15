//! The CLI. Mirrors the BE escript surface: `spgen <target> <element>
//! [options]`, bare `spgen` lists targets. Groups compose artifacts;
//! artifacts stay individually addressable; `--check` writes nothing and
//! prints the same report in future tense.

use std::path::{Path, PathBuf};

use spgen_model::{Citizen, ElementKind, Model};

use spgen_fe::{blueprints, layout::Layout, report::Report};

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();

    let mut check = false;
    let mut force = false;
    let mut model_option: Option<PathBuf> = None;
    let mut root_option: Option<PathBuf> = None;
    let mut positional: Vec<String> = Vec::new();

    let mut index = 0;
    while index < args.len() {
        match args[index].as_str() {
            "--check" => check = true,
            "--force" | "-f" => force = true,
            "--model" => {
                model_option = args.get(index + 1).map(PathBuf::from);
                index += 2;
                continue;
            }
            "--repo-root" => {
                root_option = args.get(index + 1).map(PathBuf::from);
                index += 2;
                continue;
            }
            other if other.starts_with("--") => {
                eprintln!("unknown option: {other}");
                std::process::exit(1);
            }
            other => positional.push(other.to_string()),
        }
        index += 1;
    }

    if positional.is_empty() {
        list_targets();
        return;
    }

    let target = positional[0].clone();
    let Some(members) = blueprints::resolve(&target) else {
        eprintln!("unknown target: {target}\n\nRun `spgen` to list targets.");
        std::process::exit(1);
    };

    let Some(element_name) = positional.get(1) else {
        eprintln!("usage: spgen {target} <read-model> [--check] [--force]");
        std::process::exit(1);
    };

    let repo_root = root_option.or_else(find_repo_root).unwrap_or_else(|| {
        eprintln!("error: not inside a sportipedia checkout (use --repo-root)");
        std::process::exit(1);
    });

    let model_root = model_option.unwrap_or_else(|| repo_root.join("docs/domain-model"));

    let model = Model::load(&model_root);
    let element = match model.resolve(element_name, &[ElementKind::ReadModel]) {
        Ok(element) => element,
        Err(error) => {
            eprintln!("error: {error}");
            std::process::exit(1);
        }
    };
    let citizen = match Citizen::build(&model, &element) {
        Ok(citizen) => citizen,
        Err(error) => {
            eprintln!("error: {error}");
            std::process::exit(1);
        }
    };

    // sanity: an example that fails validation is a model problem, not a
    // generator problem — report it and generate what the model does say
    let fixture_errors = Citizen::fixture_errors(&element);
    let mut report = Report::default();
    for error in fixture_errors {
        report.unresolved(format!(
            "read-model {} examples: {error}",
            citizen.constituent
        ));
    }

    let layout = Layout::new(&citizen);
    blueprints::run(
        &members,
        &citizen,
        &layout,
        &repo_root,
        check,
        force,
        &mut report,
    );

    for line in report.render() {
        println!("{line}");
    }
    std::process::exit(report.exit_code());
}

fn find_repo_root() -> Option<PathBuf> {
    let start = std::env::current_dir().ok()?;
    let mut dir: &Path = &start;
    loop {
        if dir.join("docs").join("domain-model").is_dir() && dir.join("apps").is_dir() {
            return Some(dir.to_path_buf());
        }
        dir = dir.parent()?;
    }
}

fn list_targets() {
    println!("Sportipedia blueprint generators (frontend):");
    println!();
    for (group, members) in blueprints::groups() {
        println!("  spgen {group} <read-model>   # {}", members.join(", "));
    }
    println!();
    println!("  spgen feature <read-model>     # all of the above, in build order");
    println!();
    println!("Artifacts (individually addressable, for gated re-runs):");
    for (id, _) in blueprints::artifacts() {
        println!("  spgen {id} <read-model>");
    }
    println!();
    println!(
        "Options: --check (report, write nothing), --force / -f (rewrite present generated units in place), --model <path>, --repo-root <path>"
    );
}
