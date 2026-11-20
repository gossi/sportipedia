//! The ESDM model layer of the
//! generators: reader, cross-document resolution, naming and path rules,
//! relation keywords, invariant patterns, fixture grammar, placeholder
//! engine.
//!
//! This crate holds everything language-neutral in sparch: what the domain
//! model *means*. Blueprint crates (`sparch-typescript`, `sparch-elixir`) render
//! against it; the shared fixture corpus (`fixtures/`) pins both crates to
//! the same rules.

pub mod annotations;
pub mod citizen;
pub mod element;
pub mod fields;
pub mod fixtures;
pub mod invariants;
pub mod model;
pub mod naming;
pub mod placeholders;

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
pub use invariants::{
    Validator, ValidatorKind, resolve as resolve_invariant, resolve_all as resolve_invariants,
};
pub use model::{Model, ResolveError};
pub use naming::{Case, Name, pluralize};
