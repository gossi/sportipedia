use spgen_model::ElementKind;

use crate::blueprints::schema::{Schema, Which};
use crate::context::Context;
use crate::elixir::Rank;
use crate::plan::{Blueprint, FilePlan, Placement, Unit, UnitId};

const TEST_DIR: &str =
    "services/api/test/sportipedia_web/<_subdomain>/<composite>/<domain_object>/schemas";
const FILE: &str = "services/api/test/sportipedia_web/<_subdomain>/<composite>/<domain_object>/schemas/<schema>_test.exs";

pub struct SchemaTest;

impl Blueprint for SchemaTest {
    fn name(&self) -> &'static str {
        "schema_test"
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![
            ElementKind::ReadModel,
            ElementKind::Command,
            ElementKind::Query,
        ]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(FILE, "field coverage per schema")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        Schema::whiches(ctx)
            .into_iter()
            .map(|which| test_plan(ctx, which))
            .collect()
    }
}

fn test_plan(ctx: &Context, which: Which) -> FilePlan {
    let n = Schema::names(ctx, which);
    let module = format!("{}Test", n.full);
    let mut plan = FilePlan::new(
        ctx.render_or_panic(&format!("{TEST_DIR}/{}_test.exs", n.stem)),
        Some(module.clone()),
        vec![
            use_unit(),
            alias_unit(&n.full),
            describe_unit(ctx, which, &n.short, &n.title),
        ],
    );
    plan.requires_describe = true;
    plan
}

fn use_unit() -> Unit {
    Unit {
        id: UnitId::Use("ExUnit.Case".to_string()),
        check: Box::new(|f| f.has_use("ExUnit.Case")),
        render: Box::new(|| "use ExUnit.Case".to_string()),
        place: Placement::Head {
            rank: Rank::Use,
            alias_sort_key: None,
        },
        requires: Vec::new(),
        stale: None,
    }
}

fn alias_unit(full: &str) -> Unit {
    let check_module = full.to_string();
    let render = format!("alias {full}");
    Unit {
        id: UnitId::Alias(full.to_string()),
        check: Box::new(move |f| f.has_alias(&check_module)),
        render: Box::new(move || render.clone()),
        requires: Vec::new(),
        place: Placement::Head {
            rank: Rank::Alias,
            alias_sort_key: Some(full.to_string()),
        },
        stale: None,
    }
}

fn describe_unit(ctx: &Context, which: Which, short: &str, title: &str) -> Unit {
    let subject = short.to_string();
    let check_subject = short.to_string();
    let render = test_describe(short, title);
    Unit {
        id: UnitId::Describe(subject),
        check: Box::new(move |f| f.has_describe(&check_subject)),
        render: Box::new(move || render.clone()),
        requires: vec![(
            Schema::module_file(ctx, which),
            "schema not generated (spgen schema)".to_string(),
        )],
        place: Placement::AfterDescribe,
        stale: None,
    }
}

fn test_describe(short: &str, title: &str) -> String {
    format!(
        "describe \"{short}\" do\n  test \"schema/0 has the correct title\" do\n    assert %{{title: \"{title}\"}} = {short}.schema()\n  end\n\n  test \"schema is an object\" do\n    assert %{{type: :object}} = {short}.schema()\n  end\nend"
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use crate::elixir::ElixirFile;
    use spgen_model::Model;
    use std::path::PathBuf;

    fn plans_for(name: &str) -> Vec<FilePlan> {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model
            .resolve(name, &SchemaTest.source_kinds())
            .expect("fixture element");
        let ctx =
            Context::build(&model, &element, &ContextOptions::default()).expect("context builds");
        SchemaTest.plans(&ctx)
    }

    #[test]
    fn one_test_file_per_schema_role() {
        let plans = plans_for("widget");
        let paths: Vec<String> = plans.iter().map(|p| p.path.clone()).collect();
        assert_eq!(
            paths,
            vec![
                "services/api/test/sportipedia_web/catalog/equipment/widget/schemas/widget_response_test.exs",
                "services/api/test/sportipedia_web/catalog/equipment/widget/schemas/widget_collection_response_test.exs",
            ]
        );
        assert_eq!(
            plans[0].module.as_deref(),
            Some("SportipediaWeb.Catalog.Equipment.Widget.Schemas.WidgetResponseTest")
        );
        for plan in &plans {
            assert!(plan.unit_created);
            assert!(plan.requires_describe);
        }
        assert_eq!(plans_for("create-widget").len(), 1);
        assert_eq!(plans_for("list-widgets").len(), 1);
        assert!(plans_for("archive-widget").is_empty());
    }

    #[test]
    fn the_units_are_use_alias_describe_and_the_describe_waits_for_the_schema() {
        let plan = plans_for("widget").remove(0);
        let labels: Vec<String> = plan.units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            labels,
            vec![
                "use ExUnit.Case",
                "alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.WidgetResponse",
                "describe WidgetResponse",
            ]
        );
        assert!(plan.units[0].requires.is_empty());
        assert!(plan.units[1].requires.is_empty());
        assert_eq!(
            plan.units[2].requires,
            vec![(
                "services/api/lib/sportipedia_web/catalog/equipment/widget/schemas/widget_response.ex"
                    .to_string(),
                "schema not generated (spgen schema)".to_string(),
            )]
        );
    }

    #[test]
    fn the_describe_asserts_title_and_object_type() {
        let plan = plans_for("widget").remove(0);
        let render = (plan
            .units
            .iter()
            .find(|u| u.id.label() == "describe WidgetResponse")
            .expect("describe")
            .render)();
        assert_eq!(
            render,
            "describe \"WidgetResponse\" do\n  test \"schema/0 has the correct title\" do\n    assert %{title: \"equipment.Widget\"} = WidgetResponse.schema()\n  end\n\n  test \"schema is an object\" do\n    assert %{type: :object} = WidgetResponse.schema()\n  end\nend"
        );
        let file = ElixirFile::parse(&format!(
            "defmodule T do\n  use ExUnit.Case\n  alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.WidgetResponse\n{render}\nend\n"
        ));
        for unit in &plan.units {
            assert!((unit.check)(&file), "{} must read present", unit.id.label());
        }
    }

    #[test]
    fn the_request_and_query_params_companions_name_their_own_module() {
        let request = plans_for("create-widget").remove(0);
        assert_eq!(
            request.path,
            "services/api/test/sportipedia_web/catalog/equipment/widget/schemas/create_widget_request_test.exs"
        );
        assert_eq!(
            request.module.as_deref(),
            Some("SportipediaWeb.Catalog.Equipment.Widget.Schemas.CreateWidgetRequestTest")
        );
        assert_eq!(request.units[2].id.label(), "describe CreateWidgetRequest");
        let params = plans_for("list-widgets").remove(0);
        assert_eq!(
            params.units[2].id.label(),
            "describe ListWidgetsQueryParams"
        );
    }
}
