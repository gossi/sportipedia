//! The `sparch` CLI: the crossover face, built on clap — subcommands,
//! generated help, `--version`, typed options. `sparch mcp` launches the
//! stdio server; every other verb answers through the same query API
//! the MCP tools use.

use std::path::{Path, PathBuf};

use clap::{Args, Parser, Subcommand, ValueEnum};

use crate::arch::Query;

#[derive(Parser)]
#[command(
    name = "sparch",
    version,
    about = "sparch — the blueprint generators' own tool",
    after_help = "The tiers: blueprints render units; generators run blueprints; suites run generators.\nThe generators themselves are reached by operators through the bindings: mix sp.gen.* and pnpm spgen.",
    arg_required_else_help = true
)]
pub struct Cli {
    #[command(subcommand)]
    command: Cmd,
}

#[derive(Subcommand)]
pub enum Cmd {
    /// no arguments: the capability list; with them, run a generator or suite
    Generate(GenerateArgs),
    /// model completeness (the sp.check rules) — writes nothing
    Validate(ValidateArgs),
    /// the manual page of a generator, or the index when no generator is given
    Man(ManArgs),
    /// where generated code lives (location) or what it is named (name)
    Arch(ArchArgs),
    /// the capability tree as text
    Capabilities(CapabilityArgs),
    /// start the MCP server on stdio (read-only tools)
    Mcp,
}

#[derive(Args)]
pub struct GenerateArgs {
    /// generator or suite name: read_model, command, …, operation, endpoint, feature
    pub name: Option<String>,
    /// the element: esdm: reference, *.esdm.yaml, kind.name, or bare name
    pub element: Option<String>,
    /// elixir|typescript — required only where a name exists in both languages
    #[arg(long)]
    pub target: Option<String>,
    /// what the operation does: create|update|delete|none|read|collection
    #[arg(long)]
    pub template: Option<String>,
    #[arg(long)]
    pub subdomain: Option<String>,
    #[arg(long)]
    pub composite: Option<String>,
    #[arg(long)]
    pub constituent: Option<String>,
    /// model root, default docs/domain-model (relative to --root)
    #[arg(long)]
    pub model: Option<String>,
    /// repo root, default inferred from the current directory
    #[arg(long)]
    pub root: Option<String>,
    /// report the drift, write nothing
    #[arg(long)]
    pub dry_run: bool,
    /// with --dry-run, list the units that would land, wait, or block
    #[arg(long)]
    pub verbose: bool,
    /// FE: rewrite present generated units in place
    #[arg(long, short = 'f')]
    pub force: bool,
}

#[derive(Args)]
pub struct ValidateArgs {
    /// directories or element addresses; empty checks the whole model
    pub targets: Vec<String>,
    /// repo root, default inferred from the current directory
    #[arg(long)]
    pub root: Option<String>,
    /// model root relative to --root, default docs/domain-model
    #[arg(long)]
    pub model: Option<String>,
}

#[derive(Args)]
pub struct ManArgs {
    /// the generator whose page to show; omit for the index
    pub generator: Option<String>,
    #[arg(long, help = "list the blueprint docs instead of a man page")]
    pub index: bool,
    #[arg(
        long,
        help = "elixir|typescript, needed where a name exists in both languages"
    )]
    pub target: Option<String>,
    #[arg(long, help = "plain text rather than the pager")]
    pub plain: bool,
    #[arg(long, help = "the raw roff the page is rendered from")]
    pub roff: bool,
    #[arg(
        long,
        value_name = "DIR",
        num_args = 0..=1,
        default_missing_value = "",
        help = "export the roff pages (default tools/sparch/man/roff)"
    )]
    pub write: Option<String>,
}

#[derive(Args)]
pub struct ArchArgs {
    #[arg(value_enum)]
    pub question: Question,
    /// the generator (or FE artifact/group) to ask about
    pub generator: String,
    /// the element, same addressing as a generator run
    pub element: String,
    #[arg(long)]
    pub target: Option<String>,
    #[arg(long)]
    pub subdomain: Option<String>,
    #[arg(long)]
    pub composite: Option<String>,
    #[arg(long)]
    pub constituent: Option<String>,
    /// repo root, default inferred from the current directory
    #[arg(long)]
    pub root: Option<String>,
    #[arg(long)]
    pub model: Option<String>,
}

#[derive(ValueEnum, Clone, Copy)]
pub enum Question {
    Location,
    Name,
}

#[derive(Args)]
pub struct CapabilityArgs {
    /// limit the tree to one language
    #[arg(long)]
    pub target: Option<String>,
}

pub fn run(cli: Cli, cwd: &Path) -> i32 {
    match cli.command {
        Cmd::Generate(args) => crate::generate::run(&args, cwd),
        Cmd::Validate(args) => run_validate(&args, cwd),
        Cmd::Man(args) => run_man(&args, cwd),
        Cmd::Arch(args) => run_arch(&args, cwd),
        Cmd::Capabilities(args) => {
            print!(
                "{}",
                crate::capabilities::build().render(args.target.as_deref())
            );
            0
        }
        Cmd::Mcp => run_mcp(),
    }
}

/// Entry for main.rs and tests: parse argv then dispatch.
pub fn main(argv: impl Iterator<Item = String>) -> i32 {
    let cwd = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
    let cli =
        Cli::try_parse_from(std::iter::once("sparch".to_string()).chain(argv.collect::<Vec<_>>()));
    match cli {
        Ok(cli) => run(cli, &cwd),
        Err(error) => error.exit(),
    }
}

fn run_validate(args: &ValidateArgs, cwd: &Path) -> i32 {
    match crate::validate::run(&crate::validate::Options {
        targets: args.targets.clone(),
        repo_root: args.root.as_deref().map(PathBuf::from),
        model: args.model.clone(),
        cwd: cwd.to_path_buf(),
    }) {
        Err(message) => {
            eprintln!("error: {message}");
            1
        }
        Ok(report) => {
            for line in report.render() {
                println!("{line}");
            }
            if report.complete { 0 } else { 1 }
        }
    }
}

fn run_man(args: &ManArgs, cwd: &Path) -> i32 {
    if args.index {
        print!("{}", crate::man::index());
        return 0;
    }
    if let Some(dir) = &args.write {
        return write_pages(dir, cwd);
    }
    let format = match (args.roff, args.plain) {
        (true, _) => crate::man::Format::Roff,
        (_, true) => crate::man::Format::Plain,
        _ => crate::man::Format::Pager,
    };
    crate::man::serve(args.generator.as_deref(), args.target.as_deref(), format)
}

fn write_pages(dir: &str, cwd: &Path) -> i32 {
    let path = match dir.is_empty() {
        true => sparch_elixir::engine::find_root(cwd).join(crate::manpage::ROFF_DIR),
        false => PathBuf::from(dir),
    };
    match crate::manpage::write(&path) {
        Ok(written) => {
            for file in written {
                println!("{file}");
            }
            0
        }
        Err(message) => {
            eprintln!("error: {message}");
            1
        }
    }
}

fn run_arch(args: &ArchArgs, cwd: &Path) -> i32 {
    let question = match args.question {
        Question::Location => "location",
        Question::Name => "name",
    };
    let q = Query {
        generator: args.generator.clone(),
        element: args.element.clone(),
        target: args.target.clone(),
        subdomain: args.subdomain.clone(),
        composite: args.composite.clone(),
        constituent: args.constituent.clone(),
        repo_root: args.root.as_deref().map(PathBuf::from).unwrap_or_default(),
        model: args.model.as_deref().map(PathBuf::from),
    };
    match crate::arch::answer(question, &q, cwd) {
        Err(message) => {
            eprintln!("error: {message}");
            1
        }
        Ok(answers) => {
            for (key, value) in answers {
                println!("{key}: {value}");
            }
            0
        }
    }
}

/// The MCP server is its own binary; running it from `sparch` is the
/// convenience entry. exec keeps stdio untouched for the client.
fn run_mcp() -> i32 {
    let exe = std::env::current_exe().ok();
    let candidates: Vec<PathBuf> = exe
        .as_ref()
        .and_then(|p| p.parent().map(|d| d.join("sparch-mcp")))
        .into_iter()
        .collect();
    for candidate in &candidates {
        if candidate.is_file() {
            #[cfg(unix)]
            {
                use std::os::unix::process::CommandExt;
                let error = std::process::Command::new(candidate).exec();
                eprintln!("sparch mcp: {error}");
                return 1;
            }
            #[cfg(not(unix))]
            {
                let status = std::process::Command::new(candidate)
                    .status()
                    .expect("start sparch-mcp");
                return status.code().unwrap_or(1);
            }
        }
    }
    eprintln!(
        "sparch mcp: sparch-mcp binary not found next to {exe:?} — cargo build -p sparch-mcp"
    );
    1
}
