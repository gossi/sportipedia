//! Ported from `tools/spgen/lib/sp_gen` — the ESDM model layer of the BE
//! generator: reader, cross-document resolution, context lookup, naming and
//! path rules, relation keywords, model checks.
//!
//! This crate holds everything language-neutral in spgen: what the domain
//! model *means*. Blueprint crates (`spgen-fe`) render against it; the BE
//! Elixir tool interprets the same rules in its own code, and the shared
//! fixture corpus (`fixtures/domain-model`, a copy of
//! `tools/spgen/fixtures/domain-model`) pins both.

pub mod annotations;
pub mod citizen;
pub mod element;
pub mod fields;
pub mod fixtures;
pub mod model;
pub mod naming;

pub use citizen::{
    Citizen, Command, FixtureEntry, FixtureView, Property, PropertyKind, Query, QueryKind,
    RelationView, ts_literal,
};
pub use element::{Element, ElementKind};
pub use fields::{Cardinality, Field, Relation, fields};
pub use fixtures::{
    FixtureSpec, examples_of, fixture_key, parse_key, referenced_keys,
    validate as validate_examples,
};
pub use model::{Model, ResolveError};
pub use naming::{Case, Name, pluralize};
