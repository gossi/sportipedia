use spgen_model::ElementKind;

use crate::blueprints::read_model::ReadModel;
use crate::blueprints::view::View;
use crate::context::Context;
use crate::elixir::Rank;
use crate::plan::{Blueprint, FilePlan, Placement, Unit, UnitId};
use crate::templates;

const TEST_PATH: &str = "services/api/test/sportipedia_web/<_subdomain>/<composite>/<domain_object>/<domain_object>_view_test.exs";
const TEST_MODULE: &str =
    "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ViewTest";

pub struct ViewTest;

impl Blueprint for ViewTest {
    fn name(&self) -> &'static str {
        "view_test"
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::ReadModel]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(TEST_PATH, "render tests against fixtures")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        let mut plan = FilePlan::new(
            ctx.render_or_panic(TEST_PATH),
            Some(ctx.render_or_panic(TEST_MODULE)),
            test_units(ctx),
        );
        plan.requires_describe = true;
        vec![plan]
    }
}

fn describe(subject: &str, body: &str) -> String {
    format!(
        "describe \"{subject}\" do\n{}\nend",
        templates::indent(body.trim_end(), 2)
    )
}

fn test_units(ctx: &Context) -> Vec<Unit> {
    let conn_case = "SportipediaWeb.ConnCase";
    let mut units = vec![
        Unit {
            id: UnitId::Use(conn_case.to_string()),
            check: Box::new(move |f| f.has_use(conn_case)),
            render: Box::new(move || "use SportipediaWeb.ConnCase".to_string()),
            place: Placement::Head {
                rank: Rank::Use,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        },
        describe_unit(ctx, "type/0", type_test(ctx)),
        describe_unit(ctx, "fields/0", fields_test(ctx)),
        describe_unit(ctx, "path/0", path_test(ctx)),
        describe_unit(ctx, "render show.json", render_test(ctx)),
    ];
    units.extend(alias_units(ctx));
    units
}

fn describe_unit(ctx: &Context, subject: &'static str, body: String) -> Unit {
    let render = describe(subject, &body);
    Unit {
        id: UnitId::Describe(subject.to_string()),
        check: Box::new(move |f| f.has_describe(subject)),
        render: Box::new(move || render.clone()),
        requires: view_gate(ctx),
        place: Placement::AfterDescribe,
        stale: None,
    }
}

fn alias_units(ctx: &Context) -> Vec<Unit> {
    let view = ctx.render_or_panic(View::module_template());
    let read_model = ctx.render_or_panic(ReadModel::module_template());
    vec![
        alias_unit(view, Vec::new()),
        alias_unit(
            read_model,
            vec![(
                ReadModel::module_file(ctx),
                "read model not generated (spgen read_model)".to_string(),
            )],
        ),
    ]
}

fn alias_unit(module: String, requires: Vec<(String, String)>) -> Unit {
    let check_module = module.clone();
    let render = format!("alias {module}");
    Unit {
        id: UnitId::Alias(module.clone()),
        check: Box::new(move |f| f.has_alias(&check_module)),
        render: Box::new(move || render.clone()),
        requires,
        place: Placement::Head {
            rank: Rank::Alias,
            alias_sort_key: Some(module),
        },
        stale: None,
    }
}

fn view_gate(ctx: &Context) -> Vec<(String, String)> {
    vec![(
        View::module_file(ctx),
        "view not generated (spgen view)".to_string(),
    )]
}

fn type_test(ctx: &Context) -> String {
    let view = format!("{}View", Context::pascal(&ctx.constituent));
    format!(
        "test \"returns {}\" do\n  assert {view}.type() == \"{}\"\nend\n",
        ctx.constituent, ctx.constituent
    )
}

fn fields_test(ctx: &Context) -> String {
    let view = format!("{}View", Context::pascal(&ctx.constituent));
    format!(
        "test \"returns the {} fields\" do\n  assert {view}.fields() == [{}]\nend\n",
        ctx.constituent,
        View::view_fields(ctx).join(", ")
    )
}

fn path_test(ctx: &Context) -> String {
    let view = format!("{}View", Context::pascal(&ctx.constituent));
    format!(
        "test \"returns the {} path\" do\n  assert {view}.path() == \"{}\"\nend\n",
        ctx.constituent,
        View::view_path(ctx)
    )
}

fn render_test(ctx: &Context) -> String {
    let view = format!("{}View", Context::pascal(&ctx.constituent));
    let read_model = format!("{}ReadModel", Context::pascal(&ctx.constituent));
    let attrs: Vec<String> = ctx
        .fields
        .iter()
        .filter(|f| !matches!(f.name.as_str(), "id" | "inserted_at" | "updated_at"))
        .map(|f| format!("{}: {}", f.name, templates::sample_value(ctx, f)))
        .collect();
    format!(
        "test \"produces JSON:API single document\" do\n  {constituent} = %{read_model}{{id: \"d290f1ee-6c54-4b01-90e6-d701748f0851\", {attrs}}}\n\n  conn = build_conn() |> fetch_query_params()\n\n  result = {view}.render(\"show.json\", %{{data: {constituent}, conn: conn}})\n\n  assert %{{data: %{{id: \"d290f1ee-6c54-4b01-90e6-d701748f0851\", type: \"{constituent}\"}}}} =\n           result\nend\n",
        constituent = ctx.constituent,
        attrs = attrs.join(", ")
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use spgen_model::Model;
    use std::path::PathBuf;

    fn ctx() -> Context {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model
            .resolve("widget", &[ElementKind::ReadModel])
            .expect("fixture read model");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn units() -> Vec<Unit> {
        ViewTest.plans(&ctx()).remove(0).units
    }

    fn render(units: &[Unit], label: &str) -> String {
        (units
            .iter()
            .find(|u| u.id.label() == label)
            .unwrap_or_else(|| panic!("no unit {label}"))
            .render)()
    }

    #[test]
    fn the_plan_is_the_view_test_file_created_with_its_first_describe() {
        let plan = ViewTest.plans(&ctx()).remove(0);
        assert_eq!(
            plan.path,
            "services/api/test/sportipedia_web/catalog/equipment/widget/widget_view_test.exs"
        );
        assert_eq!(
            plan.module.as_deref(),
            Some("SportipediaWeb.Catalog.Equipment.Widget.WidgetViewTest")
        );
        assert!(plan.unit_created);
        assert!(plan.requires_describe);
    }

    #[test]
    fn the_units_are_use_then_four_describes_then_the_aliases() {
        let labels: Vec<String> = units().iter().map(|u| u.id.label()).collect();
        assert_eq!(
            labels,
            vec![
                "use SportipediaWeb.ConnCase",
                "describe type/0",
                "describe fields/0",
                "describe path/0",
                "describe render show.json",
                "alias SportipediaWeb.Catalog.Equipment.Widget.WidgetView",
                "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel",
            ]
        );
    }

    #[test]
    fn the_describes_wait_for_the_view_the_read_model_alias_for_the_read_model() {
        let units = units();
        let find = |label: &str| units.iter().find(|u| u.id.label() == label).expect(label);
        for subject in ["type/0", "fields/0", "path/0", "render show.json"] {
            assert_eq!(
                find(&format!("describe {subject}")).requires,
                vec![(
                    "services/api/lib/sportipedia_web/catalog/equipment/widget/widget_view.ex"
                        .to_string(),
                    "view not generated (spgen view)".to_string(),
                )]
            );
        }
        assert!(find("use SportipediaWeb.ConnCase").requires.is_empty());
        assert!(
            find("alias SportipediaWeb.Catalog.Equipment.Widget.WidgetView")
                .requires
                .is_empty()
        );
        assert_eq!(
            find("alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel").requires,
            vec![(
                "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex".to_string(),
                "read model not generated (spgen read_model)".to_string(),
            )]
        );
    }

    #[test]
    fn the_describe_bodies_assert_on_the_view_and_a_model_seeded_literal() {
        let units = units();
        assert_eq!(
            render(&units, "describe type/0"),
            "describe \"type/0\" do\n  test \"returns widget\" do\n    assert WidgetView.type() == \"widget\"\n  end\nend"
        );
        assert_eq!(
            render(&units, "describe fields/0"),
            "describe \"fields/0\" do\n  test \"returns the widget fields\" do\n    assert WidgetView.fields() == [:title, :slug, :archivedAt, :coachId, :description, :label, :teamId]\n  end\nend"
        );
        assert_eq!(
            render(&units, "describe path/0"),
            "describe \"path/0\" do\n  test \"returns the widget path\" do\n    assert WidgetView.path() == \"catalog/equipment/widgets\"\n  end\nend"
        );
        assert_eq!(
            render(&units, "describe render show.json"),
            "describe \"render show.json\" do\n  test \"produces JSON:API single document\" do\n    widget = %WidgetReadModel{id: \"d290f1ee-6c54-4b01-90e6-d701748f0851\", title: \"Classic Widget\", slug: \"classic-widget\", archivedAt: DateTime.utc_now(), coachId: UUID.uuid5(:dns, \"equipment:coach:head-coach\"), description: \"The original widget of the fixture world\", label: \"classic\", teamId: UUID.uuid5(:dns, \"equipment:team:first-team\")}\n\n    conn = build_conn() |> fetch_query_params()\n\n    result = WidgetView.render(\"show.json\", %{data: widget, conn: conn})\n\n    assert %{data: %{id: \"d290f1ee-6c54-4b01-90e6-d701748f0851\", type: \"widget\"}} =\n             result\n  end\nend"
        );
    }

    #[test]
    fn a_written_view_test_reads_fully_present() {
        let text = "defmodule SportipediaWeb.Catalog.Equipment.Widget.WidgetViewTest do\n  use SportipediaWeb.ConnCase\n  alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel\n  alias SportipediaWeb.Catalog.Equipment.Widget.WidgetView\n\n  describe \"type/0\" do\n  end\n\n  describe \"fields/0\" do\n  end\n\n  describe \"path/0\" do\n  end\n\n  describe \"render show.json\" do\n  end\nend\n";
        let file = crate::elixir::ElixirFile::parse(text);
        for unit in &units() {
            assert!((unit.check)(&file), "{} must read present", unit.id.label());
        }
    }
}
