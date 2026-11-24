//! Blueprint registry and the generator listing that
//! `mix sp.gen` prints.
//!
//! The generator-to-blueprint mapping carries the full registry;
//! a generator whose blueprints are not ported yet is addressable but
//! answers with a pointer to the `mix sp.gen` task that still runs it. The
//! porting waves fill this list.

pub mod aggregate;
pub mod aggregate_test;
pub mod bruno;
pub mod bruno_folder;
pub mod command;
pub mod command_application;
pub mod command_handler;
pub mod command_handler_test;
pub mod command_router;
pub mod command_test;
pub mod controller;
pub mod controller_test;
pub mod event;
pub mod event_test;
pub mod factory;
pub mod fixtures;
pub mod internal_api;
pub mod lookup_query;
pub mod policy;
pub mod policy_test;
pub mod projector;
pub mod projector_supervisor;
pub mod projector_test;
pub mod public_api;
pub mod public_api_test;
pub mod query;
pub mod query_test;
pub mod read_model;
pub mod schema;
pub mod schema_test;
pub mod test_case;
pub mod validator;
pub mod view;
pub mod view_test;
pub mod web_router;
use crate::plan::{Actor, Blueprint};

/// The full BE registry: generator name, actor, and the blueprint modules
/// of the generator (head = primary).
pub const REGISTRY: &[(&str, &[&str])] = &[
    ("aggregate", &["aggregate", "aggregate_test"]),
    ("bruno", &["bruno", "bruno_folder"]),
    (
        "command",
        &[
            "command",
            "command_test",
            "command_router",
            "command_application",
        ],
    ),
    (
        "command_handler",
        &["command_handler", "command_handler_test"],
    ),
    (
        "controller",
        &["controller", "controller_test", "web_router"],
    ),
    ("event", &["event", "event_test"]),
    ("internal_api", &["internal_api"]),
    ("policy", &["policy", "policy_test"]),
    (
        "projector",
        &["projector", "projector_supervisor", "projector_test"],
    ),
    ("public_api", &["public_api", "public_api_test"]),
    ("query", &["query", "query_test"]),
    ("read_model", &["read_model"]),
    ("schema", &["schema", "schema_test"]),
    ("test_support", &["fixtures", "factory"]),
    ("view", &["view", "view_test"]),
];

/// The order generators are meant to run in — `@generator_order`. A
/// generator's writes are gated on the citizens before it, so following
/// this order needs no deferral round-trips; the listing doubles as the
/// known-good build sequence.
pub const GENERATOR_ORDER: &[&str] = &[
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
];

/// Every ported blueprint, keyed by its blueprint name — the
/// lookup dependency expansion and the registry walk use. A companion
/// module (`event_test`) is addressable through its generator's entry, not
/// as a generator of its own. A blueprint kept out of the generator
/// listing (`lookup_query`, `validator`) is addressable here
/// only: its caller's `dependencies` is what plans it.
pub fn by_name(name: &str) -> Option<&'static dyn Blueprint> {
    match name {
        "read_model" => Some(&read_model::ReadModel),
        "bruno" => Some(&bruno::Bruno),
        "bruno_folder" => Some(&bruno_folder::BrunoFolder),
        "controller" => Some(&controller::Controller),
        "controller_test" => Some(&controller_test::ControllerTest),
        "web_router" => Some(&web_router::WebRouter),
        "schema" => Some(&schema::Schema),
        "schema_test" => Some(&schema_test::SchemaTest),
        "view" => Some(&view::View),
        "view_test" => Some(&view_test::ViewTest),
        "event" => Some(&event::Event),
        "event_test" => Some(&event_test::EventTest),
        "aggregate" => Some(&aggregate::Aggregate),
        "aggregate_test" => Some(&aggregate_test::AggregateTest),
        "query" => Some(&query::Query),
        "query_test" => Some(&query_test::QueryTest),
        "internal_api" => Some(&internal_api::InternalApi),
        "lookup_query" => Some(&lookup_query::LookupQuery),
        "validator" => Some(&validator::ValidatorBlueprint),
        "command" => Some(&command::Command),
        "command_test" => Some(&command_test::CommandTest),
        "command_router" => Some(&command_router::CommandRouter),
        "command_application" => Some(&command_application::CommandApplication),
        "command_handler" => Some(&command_handler::CommandHandler),
        "command_handler_test" => Some(&command_handler_test::CommandHandlerTest),
        "projector" => Some(&projector::Projector),
        "projector_supervisor" => Some(&projector_supervisor::ProjectorSupervisor),
        "projector_test" => Some(&projector_test::ProjectorTest),
        "policy" => Some(&policy::Policy),
        "policy_test" => Some(&policy_test::PolicyTest),
        "public_api" => Some(&public_api::PublicApi),
        "public_api_test" => Some(&public_api_test::PublicAPITest),
        "fixtures" => Some(&fixtures::Fixtures),
        "factory" => Some(&factory::Factory),
        _ => None,
    }
}

/// The ported blueprint modules of a generator's registry entry, in list
/// order (head first). The run takes every module of the entry; the head
/// owns the element kinds and `--template` semantics.
/// Not-yet-ported members are skipped silently — the head defines
/// addressability, and suites keep refusing until every member generator
/// has its head ported.
pub fn generator_modules(generator: &str) -> Vec<&'static dyn Blueprint> {
    REGISTRY
        .iter()
        .find(|(name, _)| *name == generator)
        .map(|(_, modules)| modules.iter().filter_map(|m| by_name(m)).collect())
        .unwrap_or_default()
}

/// The generator's primary blueprint — the head of its registry entry,
/// when ported. This is what makes a generator addressable.
pub fn blueprint_for(generator: &str) -> Option<&'static dyn Blueprint> {
    let head = *REGISTRY
        .iter()
        .find(|(name, _)| *name == generator)?
        .1
        .first()?;
    by_name(head)
}

/// Every ported blueprint the registry lists — the closure sweep's universe.
/// A blueprint kept out of the generator listing (the validator, a lookup
/// query) forms no group of its own: it reaches the sweep inside its
/// caller's plans, from the element that caller passes.
///
/// The order is what the sweep produces: two groups back-filling the same
/// file in one round land in list order, and a file's surviving `skipped:`
/// note comes from the **last** deferred row of that path. The list carries
/// the generators alphabetically, each one's registry entry in list order.
pub fn all() -> Vec<&'static dyn Blueprint> {
    vec![
        &aggregate::Aggregate,
        &aggregate_test::AggregateTest,
        &bruno::Bruno,
        &bruno_folder::BrunoFolder,
        &command::Command,
        &command_test::CommandTest,
        &command_router::CommandRouter,
        &command_application::CommandApplication,
        &command_handler::CommandHandler,
        &command_handler_test::CommandHandlerTest,
        &controller::Controller,
        &controller_test::ControllerTest,
        &web_router::WebRouter,
        &event::Event,
        &event_test::EventTest,
        &internal_api::InternalApi,
        &policy::Policy,
        &policy_test::PolicyTest,
        &projector::Projector,
        &projector_supervisor::ProjectorSupervisor,
        &projector_test::ProjectorTest,
        &public_api::PublicApi,
        &public_api_test::PublicAPITest,
        &query::Query,
        &query_test::QueryTest,
        &read_model::ReadModel,
        &schema::Schema,
        &schema_test::SchemaTest,
        &fixtures::Fixtures,
        &factory::Factory,
        &view::View,
        &view_test::ViewTest,
    ]
}

/// The listing actor of a generator: the primary blueprint's actor once
/// ported; not-yet-ported generators keep their declaration here.
pub fn actor_for(generator: &str) -> Actor {
    match generator {
        "view" | "schema" | "controller" | "bruno" => Actor::Web,
        _ => Actor::Domain,
    }
}

/// The listing `mix sp.gen` prints: the tier vocabulary, generators
/// grouped by actor and ordered by dependency, and the suites with their
/// port status computed from their membership.
pub fn listing() -> String {
    use crate::suites::Suite;

    let mut out = String::new();
    out.push_str(
        "tiers: blueprints render units; generators run blueprints; suites run generators\n\n",
    );
    out.push_str("generators (grouped by actor, ordered by dependency):\n\n");
    for (actor, label) in [(Actor::Domain, "domain"), (Actor::Web, "web")] {
        let names: Vec<&&str> = GENERATOR_ORDER
            .iter()
            .filter(|g| REGISTRY.iter().any(|(name, _)| name == *g))
            .filter(|g| actor_for(g) == actor)
            .collect();
        out.push_str(&format!("{label}:\n"));
        for name in names {
            let status = match blueprint_for(name) {
                Some(_) => "sparch-elixir".to_string(),
                None => format!("still on the Elixir tool (mix sp.gen.{name})"),
            };
            out.push_str(&format!("  mix sp.gen.{name}  — {status}\n"));
        }
        out.push('\n');
    }
    out.push_str("suites (one scope, its generators in build order; refused until every member is ported):\n");
    for suite in [Suite::Operation, Suite::Endpoint, Suite::Feature] {
        let missing: Vec<&str> = suite
            .members()
            .iter()
            .filter(|m| blueprint_for(m).is_none())
            .copied()
            .collect();
        let status = if missing.is_empty() {
            "ready".to_string()
        } else {
            format!("pending: {}", missing.join(", "))
        };
        out.push_str(&format!("  mix sp.gen.{}  — {status}\n", suite.as_str()));
    }
    out
}
