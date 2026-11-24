//! Architectural answers: where generated code lands and what it is
//! named. The answers come from the same data the generators write from
//! — the BE path/module templates (ported to this table ahead of their
//! blueprint implementations, the strings the Elixir tool ships with)
//! and the FE `Layout`, which is the engine's own. Nothing here is a
//! restatement; `validate` does not police it, the generators use it.

use std::path::PathBuf;

use sparch_elixir::context::{Context, ContextOptions};
use sparch_model::{Case, Citizen, ElementKind, Model, Name};

/// One generator's addressable facts. `roles` pairs a role name with a
/// placeholder template — the very strings that name the files the
/// generator writes.
pub struct BeRule {
    pub name: &'static str,
    pub kinds: &'static [&'static str],
    pub roles: &'static [(&'static str, &'static str)],
}

// (path templates are written out fully in be_rule so each page reads
// like the blueprint doc it mirrors)

pub fn be_rule(name: &str) -> Option<BeRule> {
    let rule = match name {
        "read_model" => BeRule {
            name: "read_model",
            kinds: &["read-model"],
            roles: &[
                (
                    "path",
                    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/read_model.ex",
                ),
                (
                    "module",
                    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel",
                ),
            ],
        },
        "event" => BeRule {
            name: "event",
            kinds: &["event"],
            roles: &[
                (
                    "path",
                    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/events/<_event>.ex",
                ),
                (
                    "module",
                    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>",
                ),
            ],
        },
        "aggregate" => BeRule {
            name: "aggregate",
            kinds: &["aggregate", "command", "event"],
            roles: &[
                (
                    "path",
                    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/aggregate.ex",
                ),
                (
                    "module",
                    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate",
                ),
            ],
        },
        "query" => BeRule {
            name: "query",
            kinds: &["query"],
            roles: &[
                (
                    "path",
                    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/queries/<_query>.ex",
                ),
                (
                    "module",
                    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<Query>",
                ),
            ],
        },
        "internal_api" => BeRule {
            name: "internal_api",
            kinds: &["read-model", "aggregate", "command", "event", "query"],
            roles: &[
                (
                    "path",
                    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/internal.ex",
                ),
                (
                    "module",
                    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal",
                ),
            ],
        },
        "command" => BeRule {
            name: "command",
            kinds: &["command"],
            roles: &[
                (
                    "path",
                    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/operations/<_operation>/command.ex",
                ),
                (
                    "module",
                    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>",
                ),
            ],
        },
        "command_handler" => BeRule {
            name: "command_handler",
            kinds: &["command"],
            roles: &[
                (
                    "path",
                    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/operations/<_operation>/handler.ex",
                ),
                (
                    "module",
                    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>Handler",
                ),
            ],
        },
        "projector" => BeRule {
            name: "projector",
            kinds: &["event"],
            roles: &[
                (
                    "path",
                    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/projector.ex",
                ),
                (
                    "module",
                    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Projector",
                ),
            ],
        },
        "policy" => BeRule {
            name: "policy",
            kinds: &["command", "query"],
            roles: &[
                (
                    "path",
                    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/policy.ex",
                ),
                (
                    "module",
                    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Policy",
                ),
            ],
        },
        "public_api" => BeRule {
            name: "public_api",
            kinds: &["command", "query"],
            roles: &[
                (
                    "path",
                    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/public_api.ex",
                ),
                (
                    "module",
                    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>",
                ),
            ],
        },
        "test_support" => BeRule {
            name: "test_support",
            kinds: &["read-model"],
            roles: &[
                (
                    "fixtures_path",
                    "services/api/test/support/<_subdomain>/<composite>/fixtures/<domain_object>s.ex",
                ),
                (
                    "fixtures_module",
                    "Sportipedia.TestSupport.<Subdomain>.<Composite>.<DomainObject>Fixtures",
                ),
                (
                    "factory_path",
                    "services/api/test/support/<_subdomain>/<composite>/<composite>.ex",
                ),
                (
                    "factory_module",
                    "Sportipedia.TestSupport.<Subdomain>.<Composite>",
                ),
            ],
        },
        "view" => BeRule {
            name: "view",
            kinds: &["read-model"],
            roles: &[
                (
                    "path",
                    "services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>/<domain_object>_view.ex",
                ),
                (
                    "module",
                    "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>View",
                ),
            ],
        },
        "schema" => BeRule {
            name: "schema",
            kinds: &["read-model", "command", "query"],
            roles: &[(
                "directory",
                "services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>/schemas",
            )],
        },
        "controller" => BeRule {
            name: "controller",
            kinds: &["command", "query"],
            roles: &[
                (
                    "path",
                    "services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>/<domain_object>_controller.ex",
                ),
                (
                    "module",
                    "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Controller",
                ),
            ],
        },
        "bruno" => BeRule {
            name: "bruno",
            kinds: &["command", "query"],
            roles: &[("directory", "bruno/<Subdomain>/<Composite>/<Constituent>")],
        },
        _ => return None,
    };
    Some(rule)
}

/// All BE rule names (capability tree, listing).
pub fn be_rules() -> Vec<BeRule> {
    [
        "read_model",
        "test_support",
        "event",
        "aggregate",
        "query",
        "internal_api",
        "command",
        "command_handler",
        "projector",
        "policy",
        "public_api",
        "view",
        "schema",
        "controller",
        "bruno",
    ]
    .into_iter()
    .filter_map(be_rule)
    .collect()
}

/// A query against the architecture: one generator, one element, the
/// operator's location overrides. The same parameters a generator run
/// takes — that is the interface.
pub struct Query {
    pub generator: String,
    pub element: String,
    pub target: Option<String>,
    pub subdomain: Option<String>,
    pub composite: Option<String>,
    pub constituent: Option<String>,
    pub repo_root: PathBuf,
    pub model: Option<PathBuf>,
}

pub type Answers = Vec<(String, String)>;

/// Resolve `question` (location | name) over the workspace.
pub fn answer(question: &str, q: &Query, cwd: &std::path::Path) -> Result<Answers, String> {
    let target = match &q.target {
        Some(t) => t.clone(),
        None => match crate::capabilities::language_of(&q.generator) {
            Ok(one) => one.to_string(),
            Err(langs) => {
                return Err(if langs.is_empty() {
                    format!(
                        "unknown generator: {} — `sparch capabilities` lists them",
                        q.generator
                    )
                } else {
                    format!(
                        "'{}' exists in {} — pass --target {}",
                        q.generator,
                        langs.join(" and "),
                        langs.join("|")
                    )
                });
            }
        },
    };
    match target.as_str() {
        "elixir" => be_answer(question, q, cwd),
        "typescript" => typescript_answer(question, q, cwd),
        other => Err(format!("unknown target: {other} (elixir|typescript)")),
    }
}

fn be_answer(question: &str, q: &Query, cwd: &std::path::Path) -> Result<Answers, String> {
    let rule =
        be_rule(&q.generator).ok_or_else(|| format!("no BE generator named '{}'", q.generator))?;
    let model = load_model(q, cwd);
    let kinds: Vec<ElementKind> = rule.kinds.iter().map(|k| ElementKind::parse(k)).collect();
    let element = model
        .resolve(&q.element, &kinds)
        .map_err(|e| format!("cannot resolve element: {e}"))?;
    let opts = ContextOptions {
        operation: None,
        subdomain: q.subdomain.clone(),
        composite: q.composite.clone(),
        constituent: q.constituent.clone(),
        repo_root: q.repo_root.clone(),
    };
    let ctx = Context::build(&model, &element, &opts)
        .map_err(|e| format!("cannot build context: {e:?}"))?;

    let mut out: Answers = Vec::new();
    for (role, template) in rule.roles {
        // a name question answers identifiers, not file locations
        if question == "name" && (role.ends_with("path") || *role == "directory") {
            continue;
        }
        let value = ctx.render(template).map_err(|unknown| {
            format!(
                "unresolved placeholder(s): {}",
                unknown
                    .iter()
                    .map(|u| format!("<{u}>"))
                    .collect::<Vec<_>>()
                    .join(", ")
            )
        })?;
        out.push((format!("{question}:{role}"), value));
    }
    if question == "name" {
        out.extend(be_names(rule.name, &ctx, &element));
    }
    Ok(out)
}

/// The identifiers a BE generator derives for the element, beyond the
/// templates. Only facts the naming rules state, not per-port internals.
fn be_names(generator: &str, ctx: &Context, element: &sparch_model::Element) -> Answers {
    let mut out = Vec::new();
    match generator {
        "read_model" => {
            out.push((
                "name:changesets".into(),
                "insert_changeset/2, update_changeset/2".into(),
            ));
            out.push((
                "name:schema".into(),
                format!("typed_schema \"{}\"", ctx.constituent),
            ));
            out.push((
                "name:schema_prefix".into(),
                format!("@schema_prefix {:?}", ctx.subdomain),
            ));
        }
        "test_support" => {
            // the fixture function names the projection will define, from
            // the very grammar the fixtures blueprint enforces
            let plural = Name::parse(&ctx.constituent).render_plural(Case::Snake);
            let specs = sparch_model::fixtures::validate(element, &ctx.composite, &plural)
                .unwrap_or_default();
            for spec in specs {
                let fname = spec.parts.2.replace('-', "_");
                out.push((format!("name:fixture.{}", spec.key), fname));
            }
        }
        _ => {}
    }
    out
}

fn typescript_answer(question: &str, q: &Query, cwd: &std::path::Path) -> Result<Answers, String> {
    let members = sparch_typescript::blueprints::resolve(&q.generator)
        .ok_or_else(|| format!("no FE generator named '{}'", q.generator))?;
    let model = load_model(q, cwd);
    let element = model
        .resolve(&q.element, &[ElementKind::ReadModel])
        .map_err(|e| format!("cannot resolve element: {e}"))?;
    let citizen =
        Citizen::build(&model, &element).map_err(|e| format!("cannot build citizen: {e}"))?;
    let layout = sparch_typescript::layout::Layout::new(&citizen);

    let mut out: Answers = Vec::new();
    for id in members {
        let path: PathBuf = match id {
            "domain-object" => layout.domain_object(),
            "schema" => layout.schema(),
            "actions" => layout.actions(),
            "queries" => layout.queries(),
            "abilities" => layout.abilities(),
            "fixtures" => layout.fixtures(),
            "endpoints" => layout.endpoints(),
            "ability-test" => layout.ability_test(),
            "storybook" => layout.storybook(),
            _ => continue,
        };
        if question == "location" {
            out.push((format!("location:{id}"), path.display().to_string()));
        } else {
            out.push((format!("name:{id}"), naming_facts(&citizen, &layout)));
        }
    }
    Ok(out)
}

fn naming_facts(citizen: &Citizen, layout: &sparch_typescript::layout::Layout) -> String {
    format!(
        "interface {}, fields {}, plural {}",
        Name::parse(&citizen.constituent).render(Case::Pascal),
        Name::parse(&citizen.constituent).render(Case::Pascal) + "Fields",
        layout.plural
    )
}

fn load_model(q: &Query, cwd: &std::path::Path) -> Model {
    let root = if q.repo_root.as_os_str().is_empty() {
        sparch_elixir::engine::find_root(cwd)
    } else {
        q.repo_root.clone()
    };
    let model_root = match &q.model {
        Some(m) => root.join(m),
        None => root.join("docs/domain-model"),
    };
    Model::load(&model_root)
}
