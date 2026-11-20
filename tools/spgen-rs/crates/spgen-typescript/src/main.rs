//! The CLI. Mirrors the BE escript surface: `spgen <target> <element>
//! [options]`, bare `spgen` lists targets. Suites compose generators;
//! artifacts stay individually addressable; `--dry-run` writes nothing and
//! prints the same report in future tense.

use std::path::{Path, PathBuf};

use clap::Parser;

use spgen_model::{Citizen, ElementKind, Model};

use spgen_typescript::{blueprints, layout::Layout, report::Report};

#[derive(clap::Parser)]
#[command(
    name = "spgen-typescript",
    version,
    about = "FE blueprint generators — ESDM model in, TypeScript out",
    after_help = "Elements are addressed by read-model name: `spgen feature position`.\nRun without arguments to list targets; `--help` for the options."
)]
struct Cli {
    /// suite or artifact target — see the bare listing
    target: Option<String>,
    /// the read model naming the citizen
    element: Option<String>,
    /// report the drift, write nothing
    #[arg(long)]
    dry_run: bool,
    /// accepted for parity with the BE face; the FE report already lists
    /// the units per file, so there is nothing further to show
    #[arg(long)]
    verbose: bool,
    /// rewrite present generated units in place
    #[arg(long, short = 'f')]
    force: bool,
    /// model root, default <repo-root>/docs/domain-model
    #[arg(long)]
    model: Option<PathBuf>,
    /// repo root, default inferred from the current directory
    #[arg(long = "repo-root")]
    repo_root: Option<PathBuf>,
}

fn main() {
    let raw: Vec<String> = std::env::args().skip(1).collect();

    // the bare invocation stays the curated target listing
    if raw.is_empty() {
        list_targets();
        return;
    }

    let cli = match Cli::try_parse_from(std::iter::once("spgen-typescript".to_string()).chain(raw))
    {
        Ok(cli) => cli,
        Err(error) => error.exit(),
    };
    let Some(target) = cli.target else {
        list_targets();
        return;
    };
    let Some(members) = blueprints::resolve(&target) else {
        eprintln!("unknown target: {target}\n\nRun `spgen` to list targets.");
        std::process::exit(1);
    };
    let Some(element_name) = cli.element.as_deref() else {
        eprintln!("usage: spgen {target} <read-model> [--dry-run] [--force]");
        std::process::exit(1);
    };

    let repo_root = cli.repo_root.or_else(find_repo_root).unwrap_or_else(|| {
        eprintln!("error: not inside a sportipedia checkout (use --repo-root)");
        std::process::exit(1);
    });

    let model_root = cli
        .model
        .unwrap_or_else(|| repo_root.join("docs/domain-model"));

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
        cli.dry_run,
        cli.force,
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
    // one vocabulary across the tools: blueprints render units; generators
    // run blueprints; slices run generators
    println!("Sportipedia blueprint generators (frontend):");
    println!();
    println!("Suites (one scope, its generators in build order):");
    for (suite, members) in blueprints::suites() {
        println!("  spgen {suite} <read-model>   # {}", members.join(", "));
    }
    println!("  spgen feature <read-model>     # every suite above, in build order");
    println!();
    println!("Generators (individually addressable, for gated re-runs):");
    for (id, _) in blueprints::artifacts() {
        println!("  spgen {id} <read-model>");
    }
    println!();
    println!(
        "Options: --dry-run (report, write nothing), --verbose (accepted; FE output already lists units), --force / -f (rewrite present generated units in place), --model <path>, --repo-root <path>"
    );
}
