//! The generate face: `sparch generate` runs what this workspace's engines
//! can execute, in-process, and points at the final binding call for
//! everything else. After a BE write run it performs the project format
//! pass (`mix format` in services/api) the mix binding would have done,
//! reporting structurally when it cannot.

use std::path::{Path, PathBuf};

use sparch_elixir::engine::RunOptions;
use sparch_elixir::suites::Suite;

use crate::cli::GenerateArgs;

/// Entry: typed generate arguments. Returns the process exit code;
/// output goes to stdout/stderr directly, the way the engine CLIs do.
pub fn run(args: &GenerateArgs, cwd: &Path) -> i32 {
    let Some(name) = args.name.as_deref() else {
        print!("{}", crate::capabilities::build().render(None));
        return 0;
    };
    let target = match &args.target {
        Some(t) => t.clone(),
        None => match crate::capabilities::language_of(name) {
            Ok(one) => one.to_string(),
            Err(langs) if langs.is_empty() => {
                eprintln!("error: unknown generator: {name} — `sparch capabilities` lists them");
                return 1;
            }
            Err(langs) => {
                eprintln!(
                    "error: '{name}' exists in {} — pass --target {}",
                    langs.join(" and "),
                    langs.join("|")
                );
                return 1;
            }
        },
    };
    match target.as_str() {
        "elixir" => run_elixir(name, args, cwd),
        "typescript" => run_typescript(name, args, cwd),
        other => {
            eprintln!("error: unknown target: {other} (elixir|typescript)");
            1
        }
    }
}

fn root_of(args: &GenerateArgs, cwd: &Path) -> PathBuf {
    match &args.root {
        Some(root) => PathBuf::from(root),
        None => sparch_elixir::engine::find_root(cwd),
    }
}

fn run_elixir(name: &str, args: &GenerateArgs, cwd: &Path) -> i32 {
    let Some(element) = args.element.as_deref() else {
        eprintln!(
            "error: usage: mix sp.gen.{name} <element> [options]\n\n{}",
            sparch_elixir::engine::HELP
        );
        return 1;
    };
    let opts = RunOptions {
        template: args.template.clone(),
        given_template: args.template.clone(),
        subdomain: args.subdomain.clone(),
        composite: args.composite.clone(),
        constituent: args.constituent.clone(),
        model: args.model.clone(),
        root: args.root.clone(),
        dry_run: args.dry_run,
        verbose: args.verbose,
    };

    let rows = if let Some(suite) = Suite::parse(name) {
        match sparch_elixir::suites::run(suite, &opts, element, cwd) {
            Err(message) => {
                eprintln!("error: {message}");
                return 1;
            }
            Ok(rows) => rows,
        }
    } else if sparch_elixir::blueprints::blueprint_for(name).is_some() {
        // the whole registry entry, head first — the same run the
        // sparch-elixir binary performs
        let modules = sparch_elixir::blueprints::generator_modules(name);
        match sparch_elixir::engine::run(&modules, &opts, element, cwd) {
            Ok(rows) => rows,
            Err(message) => {
                eprintln!("error: {message}");
                return 1;
            }
        }
    } else {
        eprintln!(
            "generator {name} is not ported to sparch-rs yet — run it through the binding: \
             mix sp.gen.{name} {element} [options]"
        );
        return 1;
    };

    let wrote = rows.iter().any(|r| {
        matches!(
            r,
            sparch_elixir::engine::Row::Created(_)
                | sparch_elixir::engine::Row::Merged(..)
                | sparch_elixir::engine::Row::Backfill(..)
                | sparch_elixir::engine::Row::Rewritten(_)
        )
    });

    for line in sparch_elixir::engine::render_report(&rows, args.verbose) {
        println!("{line}");
    }

    if wrote
        && !args.dry_run
        && let Some(warning) = post_format(&root_of(args, cwd))
    {
        eprintln!("sparch: {warning}");
    }

    let failing = rows.iter().any(|r| {
        matches!(
            r,
            sparch_elixir::engine::Row::Error(..) | sparch_elixir::engine::Row::Blocked(..)
        )
    });
    if failing { 1 } else { 0 }
}

/// The binding's format pass, ported: run `mix format` in services/api.
/// `None` on success; a warning sentence when anything prevented it.
fn post_format(root: &Path) -> Option<String> {
    let api = root.join("services/api");
    if !api.is_dir() {
        return Some(format!(
            "format skipped — no services/api under {} (run mix format in the api project)",
            api.display()
        ));
    }
    match std::process::Command::new("mix")
        .arg("format")
        .current_dir(&api)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::piped())
        .output()
    {
        Ok(out) if out.status.success() => None,
        Ok(out) => Some(format!(
            "mix format failed (status {}): {}",
            out.status,
            String::from_utf8_lossy(&out.stderr).trim()
        )),
        Err(_) => Some(
            "format skipped — no mix on PATH; run `mix format` in services/api \
             (generated files are valid Elixir, just unformatted)"
                .to_string(),
        ),
    }
}

fn run_typescript(name: &str, args: &GenerateArgs, cwd: &Path) -> i32 {
    use sparch_model::{Citizen, ElementKind, Model};
    use sparch_typescript::{blueprints, layout::Layout, report::Report};

    let Some(members) = blueprints::resolve(name) else {
        eprintln!("error: unknown target: {name} — `sparch capabilities` lists them");
        return 1;
    };
    let Some(element_name) = args.element.as_deref() else {
        eprintln!(
            "usage: sparch generate [--target typescript] {name} <read-model> [--dry-run] [--force]"
        );
        return 1;
    };
    let root = root_of(args, cwd);
    let model_root = match &args.model {
        Some(model) => root.join(model),
        None => root.join("docs/domain-model"),
    };

    let model = Model::load(&model_root);
    let element = match model.resolve(element_name, &[ElementKind::ReadModel]) {
        Ok(e) => e,
        Err(e) => {
            eprintln!("error: {e}");
            return 1;
        }
    };
    let citizen = match Citizen::build(&model, &element) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("error: {e}");
            return 1;
        }
    };

    let mut report = Report::default();
    for error in Citizen::fixture_errors(&element) {
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
        &root,
        args.dry_run,
        args.force,
        &mut report,
    );
    for line in report.render() {
        println!("{line}");
    }
    report.exit_code()
}
