//! The query's contribution to the operation test file — ported from
//! `SpGen.Blueprint.QueryTest`
//! (`tools/spgen/lib/sp_gen/blueprint/query_test.ex`).
//!
//! A `describe "Query"` placeholder test marking the query body as the 1% the
//! blueprint leaves to the feature spec. The operation owns the file (the
//! [operation test](docs/architecture/blueprints/backend/domain/operation-test.md)
//! blueprint), so this module names the operation's path and module through
//! the shared `TestCaseFile` machinery and contributes exactly one describe —
//! with no aliases of its own, because the placeholder asserts nothing.

use crate::blueprints::test_case::{self, Describe, Options};
use crate::context::Context;
use crate::plan::{Blueprint, FilePlan};
use sparch_model::ElementKind;

const TEST_PATH: &str = "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operations/<_operation>_test.exs";
const TEST_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test";

pub struct QueryTest;

impl Blueprint for QueryTest {
    fn name(&self) -> &'static str {
        "query_test"
    }

    /// The oracle derives its sweep participation from the generator's head
    /// (`primary.accepts?`); the Rust sweep asks each ported module, so the
    /// companion names the kind it contributes to.
    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Query]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(TEST_PATH, "placeholder test for query body")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        vec![test_case::plan(
            ctx,
            Options {
                path_template: TEST_PATH,
                module_template: TEST_MODULE,
                extra_vars: Default::default(),
                // the placeholder references no citizen
                alias_templates: Vec::new(),
                alias_modules: Vec::new(),
                requires: Vec::new(),
                alias_requires: None,
                describes: vec![Describe {
                    subject_template: "Query",
                    body: Box::new(describe_body),
                    alternates: vec!["<Query> query"],
                }],
            },
        )]
    }
}

/// `QueryTest.describe_body/2` — the heredoc's own indentation: the block is
/// written at the file's top level and the placement indents it.
pub fn describe_body(_ctx: &Context, subject: &str) -> String {
    format!(
        "describe \"{subject}\" do\n  test \"is a work in progress until the spec fills it\" do\n    # the query module body is the 1% the blueprint leaves to the spec\n    assert true\n  end\nend"
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use crate::elixir::ElixirFile;
    use crate::plan::UnitId;
    use sparch_model::Model;
    use std::path::PathBuf;

    fn ctx_for(name: &str) -> Context {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model
            .resolve(name, &[ElementKind::Query])
            .expect("fixture query");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    #[test]
    fn the_plan_is_the_operation_test_file_of_the_query_itself() {
        let plan = QueryTest.plans(&ctx_for("read-widget")).remove(0);
        assert_eq!(
            plan.path,
            "services/api/test/sportipedia/catalog/equipment/widget/operations/read_widget_test.exs"
        );
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.Catalog.Equipment.Widget.Operation.ReadWidgetTest")
        );
        // shared file: it appears with the first describe that lands
        assert!(plan.requires_describe);
        assert!(plan.unit_created);
    }

    #[test]
    fn the_units_are_use_moduletag_then_the_describe() {
        let plan = QueryTest.plans(&ctx_for("list-widgets")).remove(0);
        let ids: Vec<String> = plan.units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            ids,
            vec![
                "use Sportipedia.CatalogTestCase",
                "moduletag",
                "describe Query",
            ]
        );
        // the placeholder waits for nothing: an operation test the query can
        // write on its own is still a test file
        for unit in &plan.units {
            assert!(
                unit.requires.is_empty(),
                "{} gates on nothing",
                unit.id.label()
            );
        }
    }

    #[test]
    fn the_describe_body_is_the_placeholder_case() {
        let text = describe_body(&ctx_for("read-widget"), "Query");
        assert_eq!(
            text,
            "describe \"Query\" do\n  test \"is a work in progress until the spec fills it\" do\n    # the query module body is the 1% the blueprint leaves to the spec\n    assert true\n  end\nend"
        );
        // it parses as one describe call once placed
        let file = ElixirFile::parse(&format!("defmodule T do\n{text}\nend\n"));
        assert!(file.parsed(), "{text}");
        assert!(file.has_describe("Query"));
    }

    #[test]
    fn the_check_accepts_the_spec_named_spelling() {
        // a human who replaced the placeholder with the behaviour the spec
        // states keeps their own subject; the tool does not add a second block
        let plan = QueryTest.plans(&ctx_for("read-widget")).remove(0);
        let describe = plan
            .units
            .iter()
            .find(|u| matches!(u.id, UnitId::Describe(_)))
            .expect("the describe unit");
        let adopted =
            ElixirFile::parse("defmodule T do\n  describe \"ReadWidget query\" do\n  end\nend\n");
        assert!((describe.check)(&adopted));
        let exact = ElixirFile::parse("defmodule T do\n  describe \"Query\" do\n  end\nend\n");
        assert!((describe.check)(&exact));
        let other = ElixirFile::parse(
            "defmodule T do\n  describe \"command create-widget\" do\n  end\nend\n",
        );
        assert!(!(describe.check)(&other));
    }
}
