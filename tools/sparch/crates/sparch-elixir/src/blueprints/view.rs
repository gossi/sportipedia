use sparch_model::ElementKind;

use crate::context::Context;
use crate::elixir::Rank;
use crate::plan::{Actor, Blueprint, FilePlan, Placement, Unit, UnitId};

const PATH: &str = "services/api/lib/sportipedia_web/<_subdomain>/<composite>/<domain_object>/<domain_object>_view.ex";
const MODULE: &str = "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>View";

pub struct View;

impl View {
    pub fn module_template() -> &'static str {
        MODULE
    }

    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(PATH)
    }

    pub fn view_fields(ctx: &Context) -> Vec<String> {
        ctx.fields
            .iter()
            .filter(|f| !matches!(f.name.as_str(), "id" | "inserted_at" | "updated_at"))
            // a relation is never an attribute — the linkage carries it,
            // the raw id column must not appear on the wire
            .filter(|f| f.relation.is_none())
            .map(|f| format!(":{}", f.name))
            .collect()
    }

    pub fn view_path(ctx: &Context) -> String {
        ctx.render_or_panic("<-subdomain>/<composite>/<domain-object>s")
    }

    /// The view's edges: `(relationship key, far view module, short name)`
    /// in field order, for every relation of the read model — including
    /// the parent-side virtual kinds, which are precisely the collections
    /// a compound document sideloads. `None` target (unresolved) is
    /// skipped; the integrity findings already reported it.
    pub fn relationships(ctx: &Context) -> Vec<(String, String, String)> {
        let mut out: Vec<(String, String, String)> = Vec::new();
        for f in ctx.fields.iter().filter(|f| f.name != "id") {
            let Some(relation) = &f.relation else {
                continue;
            };
            let Some(tctx) = ctx.target_context(&relation.to) else {
                continue;
            };
            let module = tctx.render_or_panic(MODULE);
            let short = module.rsplit('.').next().unwrap_or(&module).to_string();
            out.push((f.name.clone(), module, short));
        }
        out
    }

    fn relationships_text(ctx: &Context) -> String {
        let entries = View::relationships(ctx);
        let pairs = entries
            .iter()
            .map(|(name, _, short)| format!("{name}: {short}"))
            .collect::<Vec<_>>()
            .join(", ");
        format!("def relationships, do: [{pairs}]")
    }
}

impl Blueprint for View {
    fn name(&self) -> &'static str {
        "view"
    }

    fn description(&self) -> Option<&'static str> {
        Some("Generates the JSON:API view for a read model")
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::ReadModel]
    }

    fn actor(&self) -> Actor {
        Actor::Web
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(PATH, "JSON:API rendering per field")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        vec![FilePlan::new(
            ctx.render_or_panic(PATH),
            Some(ctx.render_or_panic(MODULE)),
            units(ctx),
        )]
    }
}

fn units(ctx: &Context) -> Vec<Unit> {
    let moduledoc = format!(
        "@moduledoc \"\"\"\nRenders {} resources in JSON:API format.\n\"\"\"",
        ctx.constituent
    );
    let use_text = format!("use JSONAPI.View, type: \"{}\"", ctx.constituent);
    let path_text = format!("def path, do: \"{}\"", View::view_path(ctx));
    let fields_text = format!("def fields, do: [{}]", View::view_fields(ctx).join(", "));
    let mut units = vec![
        Unit {
            id: UnitId::Moduledoc,
            check: Box::new(|f| f.has_moduledoc()),
            render: Box::new(move || moduledoc.clone()),
            place: Placement::Head {
                rank: Rank::Moduledoc,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        },
        Unit {
            id: UnitId::Use("JSONAPI.View".to_string()),
            check: Box::new(|f| f.has_use("JSONAPI.View")),
            render: Box::new(move || use_text.clone()),
            place: Placement::Head {
                rank: Rank::Use,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        },
        Unit {
            id: UnitId::Def("path".to_string(), 0),
            check: Box::new(|f| f.has_def("path", 0)),
            render: Box::new(move || path_text.clone()),
            place: Placement::BodyEnd,
            requires: Vec::new(),
            stale: None,
        },
        Unit {
            id: UnitId::Def("fields".to_string(), 0),
            check: Box::new(|f| f.has_def("fields", 0)),
            render: Box::new(move || fields_text.clone()),
            place: Placement::BodyEnd,
            requires: Vec::new(),
            stale: None,
        },
    ];

    // relationships — the view's edges, spelled as the library's
    // `def relationships` keyword list against the far views; opt-in
    // `include` is the QueryParser's job, so the plain form (no
    // `:include` tuple) always applies
    let relations = View::relationships(ctx);
    for (_name, module, short) in &relations {
        let alias_render = format!("alias {module}");
        let alias_module = module.clone();
        units.push(Unit {
            id: UnitId::Alias(module.clone()),
            check: Box::new(move |f| f.has_alias(&alias_module)),
            render: Box::new(move || alias_render.clone()),
            place: Placement::Head {
                rank: Rank::Alias,
                alias_sort_key: Some(short.clone()),
            },
            requires: Vec::new(),
            stale: None,
        });
    }
    if !relations.is_empty() {
        let relationships = View::relationships_text(ctx);
        units.push(Unit {
            id: UnitId::Def("relationships".to_string(), 0),
            check: Box::new(|f| f.has_def("relationships", 0)),
            render: Box::new(move || relationships.clone()),
            place: Placement::BodyEnd,
            requires: Vec::new(),
            stale: None,
        });
    }

    units
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use sparch_model::Model;
    use std::path::PathBuf;

    fn ctx_for(name: &str) -> Context {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model
            .resolve(name, &[ElementKind::ReadModel])
            .expect("fixture read model");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn units_for(name: &str) -> Vec<Unit> {
        View.plans(&ctx_for(name)).remove(0).units
    }

    fn render(units: &[Unit], label: &str) -> String {
        (units
            .iter()
            .find(|u| u.id.label() == label)
            .unwrap_or_else(|| panic!("no unit {label}"))
            .render)()
    }

    #[test]
    fn paths_and_modules_render_as_the_model_expects() {
        let ctx = ctx_for("widget");
        assert_eq!(
            View::module_file(&ctx),
            "services/api/lib/sportipedia_web/catalog/equipment/widget/widget_view.ex"
        );
        assert_eq!(
            ctx.render_or_panic(View::module_template()),
            "SportipediaWeb.Catalog.Equipment.Widget.WidgetView"
        );
    }

    #[test]
    fn fields_drop_id_and_timestamps_and_the_path_pluralizes() {
        let ctx = ctx_for("widget");
        assert_eq!(
            View::view_fields(&ctx),
            vec![
                ":title",
                ":slug",
                ":archived_at",
                ":coach_id",
                ":description",
                ":label",
                ":team_id"
            ]
        );
        assert_eq!(View::view_path(&ctx), "catalog/equipment/widgets");
        let apparatus = ctx_for("apparatus");
        assert_eq!(View::view_path(&apparatus), "catalog/equipment/apparatuses");
    }

    #[test]
    fn the_units_are_moduledoc_use_then_the_two_defs() {
        let units = units_for("widget");
        let labels: Vec<String> = units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            labels,
            vec!["moduledoc", "use JSONAPI.View", "path/0", "fields/0"]
        );
        assert_eq!(
            render(&units, "moduledoc"),
            "@moduledoc \"\"\"\nRenders widget resources in JSON:API format.\n\"\"\""
        );
        assert_eq!(
            render(&units, "use JSONAPI.View"),
            "use JSONAPI.View, type: \"widget\""
        );
        assert_eq!(
            render(&units, "path/0"),
            "def path, do: \"catalog/equipment/widgets\""
        );
        assert_eq!(
            render(&units, "fields/0"),
            "def fields, do: [:title, :slug, :archived_at, :coach_id, :description, :label, :team_id]"
        );
    }

    #[test]
    fn the_view_file_is_unit_created_and_ungated() {
        let ctx = ctx_for("widget");
        let plan = View.plans(&ctx).remove(0);
        assert!(plan.unit_created);
        assert!(!plan.requires_describe);
        assert_eq!(
            plan.module.as_deref(),
            Some("SportipediaWeb.Catalog.Equipment.Widget.WidgetView")
        );
        for unit in plan.units {
            assert!(
                unit.requires.is_empty(),
                "{} gates on nothing",
                unit.id.label()
            );
        }
    }

    #[test]
    fn a_written_view_reads_fully_present() {
        let text = "defmodule SportipediaWeb.Catalog.Equipment.Widget.WidgetView do\n  @moduledoc \"\"\"\n  Renders widget resources in JSON:API format.\n  \"\"\"\n  use JSONAPI.View, type: \"widget\"\n\n  def path, do: \"catalog/equipment/widgets\"\n\n  def fields, do: [:title, :slug, :archived_at, :coach_id, :description, :label, :team_id]\nend\n";
        let file = crate::elixir::ElixirFile::parse(text);
        for unit in &units_for("widget") {
            assert!((unit.check)(&file), "{} must read present", unit.id.label());
        }
    }

    #[test]
    fn relations_leave_the_attributes_and_enter_relationships() {
        let units = units_for("read-model.position");
        let fields = render(&units, "fields/0");
        assert_eq!(
            fields,
            "def fields, do: [:title, :raw_slug, :slug, :description]"
        );
        let relationships = render(&units, "relationships/0");
        assert_eq!(
            relationships,
            "def relationships, do: [apparatus: ApparatusView, instrument: InstrumentView]"
        );
        let aliases: Vec<String> = units
            .iter()
            .filter(|u| u.id.label().starts_with("alias "))
            .map(|u| (u.render)())
            .collect();
        assert!(aliases.contains(
            &"alias SportipediaWeb.Catalog.Equipment.Apparatus.ApparatusView".to_string()
        ));
    }

    #[test]
    fn a_citizen_without_relations_gets_no_relationships_unit() {
        let units = units_for("read-model.widget");
        assert!(!units.iter().any(|u| u.id.label() == "relationships/0"));
    }
}
