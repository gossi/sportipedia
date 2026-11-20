//! Shared machinery for a test file several blueprints contribute to — the
//! port of `SpGen.Blueprint.TestCaseFile`
//! (`tools/spgen/lib/sp_gen/blueprint/test_case_file.ex`).
//!
//! The file is a container; each blueprint's `*Test` module contributes its
//! own `describe` block plus the aliases it needs: the test file path and
//! module name (rendered templates), the alias modules its describes
//! reference, and its describe subject and body. Merging into an existing
//! test file appends only the missing units; the first contributor with a
//! test to write creates the file (`requires_describe: true`).

use spgen_model::placeholders::Vars;

use crate::context::Context;
use crate::elixir::Rank;
use crate::plan::{FilePlan, Placement, Unit, UnitId};

/// The subdomain's `ExUnit.CaseTemplate` — `TestCaseFile.@test_use`.
const TEST_USE: &str = "Sportipedia.<Subdomain>TestCase";

/// `TestCaseFile.test_case_module/1` — the dotted, rendered module name.
pub fn test_case_module(ctx: &Context) -> String {
    ctx.render_or_panic(TEST_USE)
}

/// A contributed describe body — `describe_body/2` of the Elixir `*Test`
/// blueprints.
type BodyFn = dyn Fn(&Context, &str) -> String;

/// One contributed `describe` block — a `{subject_template, body_fn,
/// alternates}` tuple of the Elixir version. Subject and alternates are
/// placeholder templates rendered with the plan's extra vars; the body
/// renders from the context and the rendered subject.
pub struct Describe {
    pub subject_template: &'static str,
    pub body: Box<BodyFn>,
    /// Extra subject spellings the presence check accepts besides the
    /// rendered subject itself.
    pub alternates: Vec<&'static str>,
}

/// The keyword options of `TestCaseFile.plan/2`, as data. Rust plans are
/// built per context, so the `requires` gates arrive already resolved to
/// their `[{path, reason}]` answer for this context.
pub struct Options {
    pub path_template: &'static str,
    pub module_template: &'static str,
    /// Overrides when the plan is driven from a related element.
    pub extra_vars: Vars,
    /// Module templates the describes reference, rendered with `extra_vars`.
    pub alias_templates: Vec<&'static str>,
    /// Same, already rendered (modules coming from related elements).
    pub alias_modules: Vec<String>,
    /// Gates of the describe units.
    pub requires: Vec<(String, String)>,
    /// Gates of the alias units — defaults to `requires`.
    pub alias_requires: Option<Vec<(String, String)>>,
    pub describes: Vec<Describe>,
}

/// Builds the `FilePlan` — `TestCaseFile.plan/2`.
pub fn plan(ctx: &Context, opts: Options) -> FilePlan {
    let extra_vars = &opts.extra_vars;
    let path = ctx.render_or_panic_with(opts.path_template, extra_vars);
    let module = ctx.render_or_panic_with(opts.module_template, extra_vars);
    let test_case = test_case_module(ctx);

    let mut alias_modules: Vec<String> = opts
        .alias_templates
        .iter()
        .map(|tpl| ctx.render_or_panic_with(tpl, extra_vars))
        .collect();
    alias_modules.extend(opts.alias_modules.iter().cloned());

    let alias_requires = opts
        .alias_requires
        .clone()
        .unwrap_or_else(|| opts.requires.clone());

    let mut units: Vec<Unit> = Vec::new();
    units.push(use_unit(&test_case));
    units.push(tag_unit());
    for module_name in &alias_modules {
        units.push(alias_unit(module_name, alias_requires.clone()));
    }
    for describe in opts.describes {
        units.push(describe_unit(
            ctx,
            &describe,
            extra_vars,
            opts.requires.clone(),
        ));
    }

    let mut file_plan = FilePlan::new(path, Some(module), units);
    // shared with the other contributors of this file: whoever is first to
    // have a `describe` to write creates it
    file_plan.requires_describe = true;
    file_plan
}

/// The test-case module name depends only on the subdomain, so it is
/// rendered once up front.
fn use_unit(test_case: &str) -> Unit {
    let render = format!("use {test_case}");
    let check_module = test_case.to_string();
    Unit {
        id: UnitId::Use(test_case.to_string()),
        check: Box::new(move |f| f.has_use(&check_module)),
        render: Box::new(move || render.clone()),
        place: Placement::Head {
            rank: Rank::Use,
            alias_sort_key: None,
        },
        requires: Vec::new(),
        stale: None,
    }
}

fn tag_unit() -> Unit {
    Unit {
        id: UnitId::Moduletag,
        check: Box::new(|f| f.has_attribute("moduletag")),
        render: Box::new(|| "@moduletag :integration".to_string()),
        place: Placement::Head {
            rank: Rank::Attribute,
            alias_sort_key: None,
        },
        requires: Vec::new(),
        stale: None,
    }
}

fn alias_unit(module: &str, requires: Vec<(String, String)>) -> Unit {
    let render = format!("alias {module}");
    let check_module = module.to_string();
    Unit {
        id: UnitId::TestAlias(module.to_string()),
        check: Box::new(move |f| f.has_alias(&check_module)),
        render: Box::new(move || render.clone()),
        place: Placement::Head {
            rank: Rank::Alias,
            alias_sort_key: Some(module.to_string()),
        },
        requires,
        stale: None,
    }
}

fn describe_unit(
    ctx: &Context,
    describe: &Describe,
    extra_vars: &Vars,
    requires: Vec<(String, String)>,
) -> Unit {
    let subject = ctx.render_or_panic_with(describe.subject_template, extra_vars);
    let accepted: Vec<String> = std::iter::once(subject.clone())
        .chain(
            describe
                .alternates
                .iter()
                .map(|tpl| ctx.render_or_panic_with(tpl, extra_vars)),
        )
        .collect();
    let check_accepted = accepted.clone();
    let body = (describe.body)(ctx, &subject);
    Unit {
        id: UnitId::Describe(subject),
        check: Box::new(move |f| check_accepted.iter().any(|s| f.has_describe(s))),
        render: Box::new(move || body.clone()),
        place: Placement::AfterDescribe,
        requires,
        stale: None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    fn ctx() -> Context {
        let model_root =
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = spgen_model::Model::load(&model_root.canonicalize().unwrap());
        let element = model
            .resolve("event.widget-created", &[])
            .expect("fixture event");
        Context::build(&model, &element, &crate::context::ContextOptions::default())
            .expect("context builds")
    }

    #[test]
    fn test_case_module_is_rendered_from_the_subdomain() {
        let ctx = ctx();
        assert_eq!(test_case_module(&ctx), "Sportipedia.CatalogTestCase");
    }

    #[test]
    fn plan_lands_use_moduletag_alias_then_describe() {
        let ctx = ctx();
        let file_plan = plan(
            &ctx,
            Options {
                path_template: "services/api/test/<_subdomain>/<domain_object>_test.exs",
                module_template: "Sportipedia.<Subdomain>.<DomainObject>Test",
                extra_vars: Vars::new(),
                alias_templates: vec!["Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>"],
                alias_modules: Vec::new(),
                requires: vec![(
                    "services/api/lib/sportipedia/catalog/equipment/widget/events/widget_created.ex".into(),
                    "event not generated (spgen event)".into(),
                )],
                alias_requires: None,
                describes: vec![Describe {
                    subject_template: "Event",
                    body: Box::new(|_ctx, subject| format!("describe \"{subject}\" do\nend")),
                    alternates: vec!["<Event> event"],
                }],
            },
        );
        assert_eq!(file_plan.path, "services/api/test/catalog/widget_test.exs");
        assert!(file_plan.requires_describe);
        assert!(file_plan.unit_created);
        let ids: Vec<String> = file_plan.units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            ids,
            vec![
                "use Sportipedia.CatalogTestCase",
                "moduletag",
                "test_alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated",
                "describe Event",
            ]
        );
        // gates carried per unit: the alias and the describe defer, the use
        // and the moduletag never do
        assert!(file_plan.units[0].requires.is_empty());
        assert!(file_plan.units[1].requires.is_empty());
        assert_eq!(file_plan.units[2].requires.len(), 1);
        assert_eq!(file_plan.units[3].requires.len(), 1);
    }

    #[test]
    fn describe_check_accepts_the_alternate_spellings() {
        let ctx = ctx();
        let file_plan = plan(
            &ctx,
            Options {
                path_template: "services/api/test/<_subdomain>/<domain_object>_test.exs",
                module_template: "Sportipedia.<Subdomain>.<DomainObject>Test",
                extra_vars: Vars::new(),
                alias_templates: Vec::new(),
                alias_modules: Vec::new(),
                requires: Vec::new(),
                alias_requires: None,
                describes: vec![Describe {
                    subject_template: "Event",
                    body: Box::new(|_ctx, subject| format!("describe \"{subject}\" do\nend")),
                    alternates: vec!["<Event> event"],
                }],
            },
        );
        let describe = file_plan
            .units
            .iter()
            .find(|u| matches!(u.id, UnitId::Describe(_)))
            .expect("a describe unit");
        // the alternate rendered from `<Event> event` counts as present
        let existing = crate::elixir::ElixirFile::parse(
            "defmodule T do\n  describe \"WidgetCreated event\" do\n  end\nend\n",
        );
        assert!((describe.check)(&existing));
        let other = crate::elixir::ElixirFile::parse(
            "defmodule T do\n  describe \"Aggregate\" do\n  end\nend\n",
        );
        assert!(!(describe.check)(&other));
    }

    #[test]
    fn alias_requires_can_differ_from_the_describe_gate() {
        let ctx = ctx();
        let file_plan = plan(
            &ctx,
            Options {
                path_template: "services/api/test/<_subdomain>/<domain_object>_test.exs",
                module_template: "Sportipedia.<Subdomain>.<DomainObject>Test",
                extra_vars: Vars::new(),
                alias_templates: vec!["Sportipedia.<Subdomain>.Other"],
                alias_modules: Vec::new(),
                requires: vec![("a".into(), "ra".into())],
                alias_requires: Some(vec![("b".into(), "rb".into())]),
                describes: Vec::new(),
            },
        );
        assert_eq!(file_plan.units[2].requires[0].0, "b");
    }
}
