//! The capability tree: what sparch can generate, by language, suites and
//! generators, each with the final binding call an operator types. The
//! tree is one structure with two renderers — CLI text and MCP JSON —
//! and never shows internal binaries, only `mix sp.gen.*` and
//! `pnpm spgen ...`.

use serde::Serialize;

use sparch_elixir::blueprints as be;
use sparch_elixir::suites::Suite;

use crate::arch;

#[derive(Serialize)]
pub struct Generator {
    pub name: String,
    /// The call the operator types, exactly.
    pub invocation: String,
    pub element_kinds: Vec<String>,
    pub actor: String,
    /// True when the Rust engine in this workspace can execute it.
    pub ported: bool,
    /// The blueprint manual page, when one exists in the embedded store.
    pub manual: Option<String>,
}

#[derive(Serialize)]
pub struct SuiteInfo {
    pub name: String,
    pub invocation: String,
    pub members: Vec<String>,
    /// Members the Rust engines cannot execute yet; empty means ready.
    pub pending: Vec<String>,
}

#[derive(Serialize)]
pub struct Language {
    pub language: String,
    pub suites: Vec<SuiteInfo>,
    pub generators: Vec<Generator>,
}

#[derive(Serialize)]
pub struct Capabilities {
    pub languages: Vec<Language>,
}

pub fn build() -> Capabilities {
    Capabilities {
        languages: vec![elixir(), typescript()],
    }
}

fn elixir() -> Language {
    let generators = be::GENERATOR_ORDER
        .iter()
        .filter_map(|name| arch::be_rule(name))
        .map(|rule| Generator {
            name: rule.name.to_string(),
            invocation: format!("mix sp.gen.{} <element>", rule.name),
            element_kinds: rule.kinds.iter().map(|k| k.to_string()).collect(),
            actor: match be::actor_for(rule.name) {
                sparch_elixir::plan::Actor::Domain => "domain".to_string(),
                sparch_elixir::plan::Actor::Web => "web".to_string(),
            },
            ported: be::blueprint_for(rule.name).is_some(),
            manual: crate::man::page_path(rule.name).map(str::to_string),
        })
        .collect();
    let suites = [Suite::Operation, Suite::Endpoint, Suite::Feature]
        .iter()
        .map(|suite| SuiteInfo {
            name: suite.as_str().to_string(),
            invocation: format!("mix sp.gen.{} <element>", suite.as_str()),
            members: suite.members().iter().map(|m| m.to_string()).collect(),
            pending: suite
                .members()
                .iter()
                .filter(|g| be::blueprint_for(g).is_none())
                .map(|g| g.to_string())
                .collect(),
        })
        .collect();
    Language {
        language: "elixir".into(),
        suites,
        generators,
    }
}

fn typescript() -> Language {
    let generators = sparch_typescript::blueprints::artifacts()
        .into_iter()
        .map(|(id, _)| {
            let writes_test_file = sparch_typescript::blueprints::generated_files(id)
                .iter()
                .any(|(path, _)| path.contains("/tests/"));
            Generator {
                name: id.to_string(),
                invocation: format!("pnpm spgen {id} <read-model>"),
                element_kinds: vec!["read-model".to_string()],
                actor: if writes_test_file { "test" } else { "domain" }.to_string(),
                ported: true,
                manual: crate::man::page_path(id).map(str::to_string),
            }
        })
        .collect();
    let mut suites: Vec<SuiteInfo> = sparch_typescript::blueprints::suites()
        .into_iter()
        .map(|(group, members)| SuiteInfo {
            name: group.to_string(),
            invocation: format!("pnpm spgen {group} <read-model>"),
            members: members.iter().map(|m| m.to_string()).collect(),
            pending: Vec::new(),
        })
        .collect();
    suites.push(SuiteInfo {
        name: sparch_typescript::blueprints::FEATURE.to_string(),
        invocation: "pnpm spgen feature <read-model>".to_string(),
        members: sparch_typescript::blueprints::artifacts()
            .into_iter()
            .map(|(id, _)| id.to_string())
            .collect(),
        pending: Vec::new(),
    });
    Language {
        language: "typescript".into(),
        suites,
        generators,
    }
}

impl Capabilities {
    pub fn to_json(&self, language: Option<&str>) -> serde_json::Value {
        match language {
            None => serde_json::to_value(self).expect("capabilities are serializable"),
            Some(one) => serde_json::json!({
                "languages": self.languages.iter().filter(|l| l.language == one).collect::<Vec<_>>()
            }),
        }
    }

    pub fn render(&self, language: Option<&str>) -> String {
        let mut out = String::from(
            "sparch capabilities — generators run blueprints, suites run generators\n\n",
        );
        for lang in &self.languages {
            if let Some(want) = language
                && lang.language != want
            {
                continue;
            }
            out.push_str(&format!("{}:\n", lang.language));
            for suite in &lang.suites {
                let status = if suite.pending.is_empty() {
                    String::new()
                } else {
                    format!("   [pending: {}]", suite.pending.join(", "))
                };
                out.push_str(&format!(
                    "  suite  {:<16} {}{status}\n",
                    suite.name, suite.invocation
                ));
            }
            for g in &lang.generators {
                let status = if g.ported { "" } else { "   [Elixir tool]" };
                out.push_str(&format!(
                    "  {:<6} {:<16} {}{}\n",
                    g.actor, g.name, g.invocation, status
                ));
            }
            out.push('\n');
        }
        out
    }

    pub fn language(&self, name: &str) -> Option<&Language> {
        self.languages.iter().find(|l| l.language == name)
    }
}

/// Which language a generator name belongs to. Only `schema` and the
/// suite/group names collide across languages; ambiguity is stated, not
/// guessed.
pub fn language_of(name: &str) -> Result<&'static str, Vec<&'static str>> {
    let mut found = Vec::new();
    if arch::be_rule(name).is_some() || Suite::parse(name).is_some() {
        found.push("elixir");
    }
    if sparch_typescript::blueprints::resolve(name).is_some() {
        found.push("typescript");
    }
    match found.as_slice() {
        [one] => Ok(*one),
        [] => Err(vec![]),
        many => Err(many.to_vec()),
    }
}
