//! Blueprint registry: artifact ids, suite composition, run order. The
//! suites are sugar over the generators — running a suite runs its members
//! in order through the same entry points (the BE's known-good build
//! sequence, FE edition).

use spgen_model::Citizen;

use crate::{
    layout::Layout,
    plan::{FilePlan, Presence, Unit},
    report::Report,
};

pub mod abilities;
pub mod ability_test;
pub mod actions;
pub mod domain_object;
pub mod endpoints;
pub mod fixtures;
pub mod queries;
pub mod schema;
pub mod storybook;

pub struct Output {
    pub plans: Vec<FilePlan>,
    pub notes: Vec<String>,
}

pub type Blueprint = fn(&Citizen, &Layout) -> Output;

/// Artifact ids in run order.
pub fn artifacts() -> Vec<(&'static str, Blueprint)> {
    vec![
        ("domain-object", domain_object::plan),
        ("schema", schema::plan),
        ("actions", actions::plan),
        ("queries", queries::plan),
        ("abilities", abilities::plan),
        ("fixtures", fixtures::plan),
        ("endpoints", endpoints::plan),
        ("ability-test", ability_test::plan),
        ("storybook", storybook::plan),
    ]
}

pub fn shortdoc(artifact: &str) -> &'static str {
    match artifact {
        "domain-object" => "Generates the domain object interface and its fields type",
        "schema" => "Generates the WarpDrive resource schema and the citizen's registrations",
        "actions" => "Generates one request-option builder per command",
        "queries" => "Generates one query function per model query",
        "abilities" => "Generates one ability predicate per command from the model's actors",
        "fixtures" => "Generates a frozen const and find helpers per model example",
        "endpoints" => "Generates the MSW endpoint descriptors and mock handlers",
        "ability-test" => "Generates the role truth table test of each ability",
        "storybook" => "Generates the storybook argTypes, presets and meta factory",
        other => unreachable!("shortdoc of unknown artifact {other}"),
    }
}

pub fn generated_files(artifact: &str) -> Vec<(&'static str, &'static str)> {
    match artifact {
        "domain-object" => vec![(
            "apps/<subdomain>/src/<composite>/domain-objects/<constituent>/<constituent>.ts",
            "interface and fields type",
        )],
        "schema" => vec![
            (
                "apps/<subdomain>/src/<composite>/schemas/<constituent>.ts",
                "resource schema with defaults",
            ),
            (
                "apps/<subdomain>/src/<composite>/index.ts",
                "export registration here",
            ),
            (
                "apps/<subdomain>/src/config.ts",
                "citizen registration in config",
            ),
        ],
        "actions" => vec![(
            "apps/<subdomain>/src/<composite>/domain-objects/<constituent>/actions.ts",
            "request options per command",
        )],
        "queries" => vec![(
            "apps/<subdomain>/src/<composite>/domain-objects/<constituent>/queries.ts",
            "query function per model query",
        )],
        "abilities" => vec![(
            "apps/<subdomain>/src/<composite>/domain-objects/<constituent>/abilities.ts",
            "ability predicate per command",
        )],
        "fixtures" => vec![
            (
                "apps/<subdomain>/tests/<composite>/support/fixtures/<plural>.ts",
                "frozen const and find helpers",
            ),
            (
                "apps/<subdomain>/tests/<composite>/support/index.ts",
                "test support exports",
            ),
        ],
        "endpoints" => vec![
            (
                "apps/<subdomain>/tests/<composite>/support/queries/<plural>.ts",
                "endpoint descriptors and handlers",
            ),
            (
                "apps/<subdomain>/tests/<composite>/support/index.ts",
                "test support exports",
            ),
        ],
        "ability-test" => vec![(
            "apps/<subdomain>/tests/<composite>/domain-objects/<constituent>/abilities.test.ts",
            "role truth table per ability",
        )],
        "storybook" => vec![
            (
                "apps/<subdomain>/tests/<composite>/support/storybook.ts",
                "argTypes presets and meta",
            ),
            (
                "apps/<subdomain>/tests/<composite>/support/index.ts",
                "test support exports",
            ),
        ],
        other => unreachable!("generated files of unknown artifact {other}"),
    }
}

pub fn suites() -> Vec<(&'static str, Vec<&'static str>)> {
    vec![
        (
            "domain-objects",
            vec!["domain-object", "schema", "actions", "queries", "abilities"],
        ),
        ("test-support", vec!["fixtures", "endpoints"]),
        ("ability-tests", vec!["ability-test"]),
        ("storybook", vec!["storybook"]),
    ]
}

/// `spgen feature` — all groups in build order.
pub const FEATURE: &str = "feature";

pub fn resolve(target: &str) -> Option<Vec<&'static str>> {
    if target == FEATURE {
        return Some(artifacts().iter().map(|(id, _)| *id).collect());
    }
    if let Some((_, members)) = suites().iter().find(|(name, _)| *name == target) {
        return Some(members.clone());
    }
    artifacts()
        .iter()
        .find(|(id, _)| *id == target)
        .map(|(id, _)| vec![*id])
}

pub fn run(
    target_ids: &[&'static str],
    citizen: &Citizen,
    layout: &Layout,
    repo_root: &std::path::Path,
    dry_run: bool,
    force: bool,
    report: &mut Report,
) {
    let registry = artifacts();
    for id in target_ids {
        let Some((_, blueprint)) = registry.iter().find(|(name, _)| name == id) else {
            continue;
        };
        let output = blueprint(citizen, layout);
        for note in output.notes {
            report.unresolved(note);
        }
        for plan in output.plans {
            crate::plan::run_plan(&plan, repo_root, dry_run, force, report);
        }
    }
}

// -------------------------------------------------------------- unit helpers

/// A top-level declaration unit; id doubles as the declaration name.
pub fn declaration(name: &str, text: impl Into<String>) -> Unit {
    Unit {
        id: name.to_string(),
        text: text.into(),
        presence: Presence::Declaration(name.to_string()),
        place: crate::plan::Place::Eof,
        member: None,
        gate: Vec::new(),
        companions: vec![],
    }
}

pub fn test(title: impl Into<String>, text: impl Into<String>) -> Unit {
    let title = title.into();
    Unit {
        id: format!("test('{title}')"),
        text: text.into(),
        presence: Presence::TestTitle(title),
        place: crate::plan::Place::Eof,
        member: None,
        gate: Vec::new(),
        companions: vec![],
    }
}

pub fn test_gated(title: &str, text: impl Into<String>, gates: Vec<std::path::PathBuf>) -> Unit {
    let mut unit = test(title, text);
    unit.gate = gates;
    unit
}

pub fn import(source: &str, type_only: bool, specifier: &str) -> Unit {
    Unit {
        id: format!("import {specifier} from {source}"),
        text: specifier.to_string(),
        presence: Presence::Import {
            source: source.to_string(),
            type_only,
            specifier: specifier.to_string(),
        },
        place: crate::plan::Place::Import {
            source: source.to_string(),
            type_only,
        },
        member: None,
        gate: Vec::new(),
        companions: vec![],
    }
}

pub fn member(anchor: &str, name: &str) -> Unit {
    Unit {
        id: format!("{name} in {anchor}"),
        text: String::new(),
        presence: Presence::Member {
            anchor: anchor.to_string(),
            member: name.to_string(),
        },
        place: crate::plan::Place::Member {
            anchor: anchor.to_string(),
        },
        member: Some(name.to_string()),
        gate: Vec::new(),
        companions: vec![],
    }
}

pub fn block(source: &str, text: impl Into<String>) -> Unit {
    Unit {
        id: format!("export block from {source}"),
        text: text.into(),
        presence: Presence::Line(format!("from '{source}'")),
        place: crate::plan::Place::AppendText,
        member: None,
        gate: Vec::new(),
        companions: vec![],
    }
}

pub fn block_member(source: &str, name: &str) -> Unit {
    Unit {
        id: format!("{name} in {source}"),
        text: String::new(),
        presence: Presence::BlockMember {
            source: source.to_string(),
            member: name.to_string(),
        },
        place: crate::plan::Place::BlockMember {
            source: source.to_string(),
        },
        member: Some(name.to_string()),
        gate: Vec::new(),
        companions: vec![],
    }
}

/// A test-support barrel plan for one artifact's block. The barrel obeys
/// the BE registration rule — *created by the blueprint that writes into
/// it* — so fixtures, endpoints and storybook each own their block: the
/// first artifact whose file actually materializes creates the barrel,
/// the others append their block to the existing file.
///
/// `gate` is the artifact's own file gate: while the citizen file would
/// not be created, its block must not be exported either — a barrel
/// importing an absent module would break the tree, and the tree must
/// stay compilable after every run.
pub fn barrel_plan(
    layout: &Layout,
    source: &str,
    names: &[String],
    gate: Vec<std::path::PathBuf>,
) -> FilePlan {
    let block_text = format!("export {{\n  {}\n}} from '{source}';", names.join(",\n  "));
    let mut block_unit = block(source, block_text.clone());
    block_unit.gate = gate.clone();
    let mut units = vec![block_unit];
    for name in names {
        let mut member = block_member(source, name);
        member.gate = gate.clone();
        units.push(member);
    }
    for name in names {
        let mut member = block_member(source, name);
        member.gate = gate.clone();
        units.push(member);
    }

    FilePlan {
        path: layout.test_barrel(),
        host: false,
        create: Some(format!("{block_text}\n")),
        units,
    }
}

pub fn line(needle: &str, text: impl Into<String>) -> Unit {
    Unit {
        id: needle.to_string(),
        text: text.into(),
        presence: Presence::Line(needle.to_string()),
        place: crate::plan::Place::AfterLine {
            needle: needle.to_string(),
        },
        member: None,
        gate: Vec::new(),
        companions: vec![],
    }
}

pub fn gated(mut unit: Unit, gate: std::path::PathBuf) -> Unit {
    unit.gate = vec![gate];
    unit
}

pub fn out(plans: Vec<FilePlan>) -> Output {
    Output {
        plans,
        notes: vec![],
    }
}

pub fn jsdoc(lines: &[&str]) -> String {
    let mut text = String::from("/**\n");
    for line in lines {
        text.push_str(" * ");
        text.push_str(line);
        text.push('\n');
    }
    text.push_str(" */\n");
    text
}

/// `'a' | 'b' | 'c'` for type-level unions.
pub fn union(names: &[String]) -> String {
    names
        .iter()
        .map(|n| format!("'{n}'"))
        .collect::<Vec<_>>()
        .join(" | ")
}

pub fn quote_list(names: &[String]) -> String {
    names
        .iter()
        .map(|n| format!("'{n}'"))
        .collect::<Vec<_>>()
        .join(", ")
}
