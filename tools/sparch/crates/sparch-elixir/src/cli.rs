//! CLI entry — the port of `SpGen.CLI`, argument syntax now carried by
//! clap (the default experience: generated help, `--version`, typed
//! flags). One run per process: resolve the generator or suite, run it,
//! print the report, choose the exit code. A Failed or Blocked row exits
//! 1; a deferral, an outdated line or an unresolved rule stays guidance
//! (exit 0), README decision 10.
//!
//! The bare invocation (no arguments) stays the curated generator-and-
//! suite listing: it reads no repository and is the entry the bindings
//! and humans hit first. Everything with arguments is clap.

use std::path::{Path, PathBuf};

use clap::Parser;

use crate::blueprints;
use crate::engine::{self, Row, RunOptions};
use crate::suites;

#[derive(Parser)]
#[command(
    name = "sparch-elixir",
    version,
    about = "BE blueprint generators — ESDM domain model in, Elixir code out",
    after_help = engine::HELP
)]
struct Cli {
    /// generator or suite name: read_model, command, event, …, operation,
    /// endpoint, feature
    generator: Option<String>,
    /// the element: esdm: reference, *.esdm.yaml, kind.name, or bare name
    element: Option<String>,
    /// what the operation does: create|update|delete|none|read|collection
    #[arg(long)]
    template: Option<String>,
    /// override the inferred subdomain
    #[arg(long)]
    subdomain: Option<String>,
    /// override the inferred composite
    #[arg(long)]
    composite: Option<String>,
    /// override the inferred constituent (domain object)
    #[arg(long)]
    constituent: Option<String>,
    /// model root, default docs/domain-model (relative to --root)
    #[arg(long)]
    model: Option<String>,
    /// repo root, default inferred from the current directory
    #[arg(long)]
    root: Option<String>,
    /// report the drift, write nothing
    #[arg(long)]
    dry_run: bool,
    /// with --dry-run, list the units that would land, wait, or block
    #[arg(long)]
    verbose: bool,
}

pub fn main(argv: impl Iterator<Item = String>) -> i32 {
    let args: Vec<String> = argv.collect();
    let cwd = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));

    if args.is_empty() {
        print!("{}", blueprints::listing());
        return 0;
    }

    let cli = match Cli::try_parse_from(
        std::iter::once("sparch-elixir".to_string()).chain(args.iter().cloned()),
    ) {
        Ok(cli) => cli,
        Err(error) => error.exit(),
    };
    let Some(generator) = cli.generator else {
        print!("{}", blueprints::listing());
        return 0;
    };

    let opts = RunOptions {
        template: cli.template.clone(),
        given_template: cli.template,
        subdomain: cli.subdomain,
        composite: cli.composite,
        constituent: cli.constituent,
        model: cli.model,
        root: cli.root,
        dry_run: cli.dry_run,
        verbose: cli.verbose,
    };
    let verbose = opts.verbose;

    if generator == "validate" {
        eprintln!(
            "error: model validation lives in the sparch binary — run `sparch validate` or `mix sp.validate`"
        );
        return 1;
    }

    let Some(element) = cli.element.as_deref() else {
        eprintln!(
            "error: usage: mix sp.gen.{generator} <element> [options]\n\n{}",
            engine::help()
        );
        return 1;
    };

    if let Some(suite) = suites::Suite::parse(&generator) {
        return match suites::run(suite, &opts, element, &cwd) {
            Err(message) => {
                // the oracle's die/1 contract: stderr, "error: " prefix, exit 1
                eprintln!("error: {message}");
                1
            }
            Ok(rows) => finish(rows, verbose),
        };
    }
    run(&generator, &opts, element, &cwd, verbose)
}

fn run(generator: &str, opts: &RunOptions, element: &str, cwd: &Path, verbose: bool) -> i32 {
    if blueprints::blueprint_for(generator).is_none() {
        eprintln!(
            "generator {generator} is not ported to sparch-elixir yet — use mix sp.gen.{generator} \
             (the Elixir tool stays live until the parity gate passes)"
        );
        return 1;
    }
    // the whole registry entry, head first: the ported blueprint modules
    // of one run, exactly as the Elixir tool runs them
    let modules = blueprints::generator_modules(generator);
    match engine::run(&modules, opts, element, cwd) {
        Err(message) => {
            eprintln!("error: {message}");
            1
        }
        Ok(rows) => finish(rows, verbose),
    }
}

/// One merged report for a generator run or a suite; a Failed or Blocked
/// row exits 1, guidance exits 0.
fn finish(rows: Vec<Row>, verbose: bool) -> i32 {
    for line in engine::render_report(&rows, verbose) {
        println!("{line}");
    }
    let failing = rows
        .iter()
        .any(|r| matches!(r, Row::Error(..) | Row::Blocked(..)));
    if failing { 1 } else { 0 }
}
