use sparch_model::ElementKind;

use crate::blueprints::read_model::ReadModel;
use crate::context::Context;
use crate::elixir::{ElixirFile, Rank};
use crate::plan::{Blueprint, ClosureScope, Dependency, FilePlan, Placement, Stale, Unit, UnitId};

const PATH: &str = "services/api/test/support/<_subdomain>/<composite>/<composite>.ex";
const MODULE: &str = "Sportipedia.TestSupport.<Subdomain>.<Composite>";
const READ_MODEL_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel";

pub struct Factory;

impl Factory {
    pub fn module_template() -> &'static str {
        MODULE
    }

    pub fn path_template() -> &'static str {
        PATH
    }

    pub fn module_name(ctx: &Context) -> String {
        ctx.render_or_panic(MODULE)
    }

    pub fn seed_name(ctx: &Context) -> String {
        format!("new_{}", ctx.constituent.replace('-', "_"))
    }

    pub fn seed_all_name(ctx: &Context) -> String {
        format!("new_{}", ctx.render_or_panic("<domain_object>s"))
    }

    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(PATH)
    }
}

fn rm_module(ctx: &Context) -> String {
    ctx.render_or_panic(READ_MODEL_MODULE)
}

fn local(ctx: &Context) -> String {
    rm_module(ctx)
        .rsplit('.')
        .next()
        .unwrap_or_default()
        .to_string()
}

fn repo_module(ctx: &Context) -> String {
    format!("Sportipedia.{}.Repo", Context::pascal(&ctx.subdomain))
}

fn gate_reason(ctx: &Context) -> String {
    format!(
        "the {} read model does not exist (sparch read_model)",
        ctx.constituent
    )
}

fn read_model_gate(ctx: &Context) -> Vec<(String, String)> {
    vec![(ReadModel::module_file(ctx), gate_reason(ctx))]
}

impl Blueprint for Factory {
    fn name(&self) -> &'static str {
        "factory"
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::ReadModel]
    }

    fn closure_scope(&self) -> ClosureScope {
        ClosureScope::None
    }

    fn dependencies(&self, ctx: &Context) -> Vec<Dependency> {
        vec![Dependency {
            blueprint_name: "read_model",
            element: ctx.element.clone(),
        }]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(PATH, "factory functions per example")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        vec![FilePlan {
            path: ctx.render_or_panic(PATH),
            module: Some(ctx.render_or_panic(MODULE)),
            units: units(ctx),
            scaffold: None,
            format: true,
            unit_created: true,
            requires_describe: false,
            projection: false,
            gate: Vec::new(),
        }]
    }
}

fn units(ctx: &Context) -> Vec<Unit> {
    vec![
        moduledoc_unit(ctx),
        repo_alias_unit(ctx),
        read_model_alias_unit(ctx),
        seed_pair_unit(ctx),
        seed_all_unit(ctx),
    ]
}

fn moduledoc_unit(ctx: &Context) -> Unit {
    let render = format!(
        "@moduledoc \"\"\"\nTest-support factories for the {} composite — they turn\nfixtures (or plain attribute maps) into persisted read models.\nGenerated `new_*` units append per read model; the file is a ledger.\n\"\"\"",
        ctx.composite
    );
    Unit {
        id: UnitId::Moduledoc,
        check: Box::new(|f: &ElixirFile| f.has_moduledoc()),
        render: Box::new(move || render.clone()),
        place: Placement::Head {
            rank: Rank::Moduledoc,
            alias_sort_key: None,
        },
        requires: Vec::new(),
        stale: None,
    }
}

fn repo_alias_unit(ctx: &Context) -> Unit {
    let module = repo_module(ctx);
    let render = format!("alias {module}");
    let check_module = module.clone();
    Unit {
        id: UnitId::Alias(module.clone()),
        check: Box::new(move |f: &ElixirFile| f.has_alias(&check_module)),
        render: Box::new(move || render.clone()),
        requires: Vec::new(),
        place: Placement::Head {
            rank: Rank::Alias,
            alias_sort_key: Some(module),
        },
        stale: None,
    }
}

fn read_model_alias_unit(ctx: &Context) -> Unit {
    let module = rm_module(ctx);
    let render = format!("alias {module}");
    let check_module = module.clone();
    let requires = read_model_gate(ctx);
    Unit {
        id: UnitId::Alias(module.clone()),
        check: Box::new(move |f: &ElixirFile| f.has_alias(&check_module)),
        render: Box::new(move || render.clone()),
        requires,
        place: Placement::Head {
            rank: Rank::Alias,
            alias_sort_key: Some(module),
        },
        stale: None,
    }
}

fn seed_pair_unit(ctx: &Context) -> Unit {
    let name = Factory::seed_name(ctx);
    let struct_key = format!("{}{{}}", local(ctx));
    let notice = format!(
        "{name}/1 has no fixture-struct clause — add `def {name}(%{}{{}} = fixture), do: {name}(Map.from_struct(fixture))`",
        local(ctx)
    );
    let render = render_seed_pair(ctx);
    let check_name = name.clone();
    let check_key = struct_key.clone();
    let stale_name = name.clone();
    let stale_key = struct_key.clone();
    let requires = read_model_gate(ctx);
    let stale: Stale = Some(Box::new(move |file: &ElixirFile| {
        if !file.has_def(&stale_name, 1) || file.has_def_head_arg(&stale_name, 1, &stale_key) {
            Vec::new()
        } else {
            vec![notice.clone()]
        }
    }));
    Unit {
        id: UnitId::Defs(name),
        check: Box::new(move |f: &ElixirFile| f.has_def_head_arg(&check_name, 1, &check_key)),
        render: Box::new(move || render.clone()),
        requires,
        place: Placement::BodyEnd,
        stale,
    }
}

fn render_seed_pair(ctx: &Context) -> String {
    let name = Factory::seed_name(ctx);
    let local = local(ctx);
    format!(
        "@spec {name}({local}.t() | map()) ::\n        {{:ok, {local}.t()}} | {{:error, Ecto.Changeset.t()}}\ndef {name}(%{local}{{}} = fixture) do\n  {name}(Map.from_struct(fixture))\nend\n\ndef {name}(attributes) when is_map(attributes) do\n  %{local}{{}}\n  |> {local}.insert_changeset(attributes)\n  |> Repo.insert()\nend"
    )
}

fn seed_all_unit(ctx: &Context) -> Unit {
    let name = Factory::seed_all_name(ctx);
    let singular = Factory::seed_name(ctx);
    let one = ctx.constituent.clone();
    let local = local(ctx);
    let render = format!(
        "@spec {name}([{local}.t() | map()]) :: [{local}.t()]\ndef {name}(attribute_collection) do\n  Enum.map(attribute_collection, fn attributes ->\n    case {singular}(attributes) do\n      {{:ok, {one}}} -> {one}\n      {{:error, changeset}} ->\n        raise \"seeding {one} fixture failed: #{{inspect(changeset.errors)}}\"\n    end\n  end)\nend"
    );
    let check_name = name.clone();
    let requires = read_model_gate(ctx);
    Unit {
        id: UnitId::Def(name, 1),
        check: Box::new(move |f: &ElixirFile| f.has_def(&check_name, 1)),
        render: Box::new(move || render.clone()),
        requires,
        place: Placement::AfterDef {
            name: singular,
            arity: 1,
        },
        stale: None,
    }
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
        Factory.plans(&ctx_for(name)).remove(0).units
    }

    fn unit<'a>(units: &'a [Unit], label: &str) -> &'a Unit {
        units
            .iter()
            .find(|u| u.id.label() == label)
            .unwrap_or_else(|| panic!("no unit {label}"))
    }

    fn render(units: &[Unit], label: &str) -> String {
        (unit(units, label).render)()
    }

    fn labels(units: &[Unit]) -> Vec<String> {
        units.iter().map(|u| u.id.label()).collect()
    }

    #[test]
    fn the_ledger_file_carries_one_unit_block_per_read_model() {
        let plan = Factory.plans(&ctx_for("widget")).remove(0);
        assert_eq!(
            plan.path,
            "services/api/test/support/catalog/equipment/equipment.ex"
        );
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.TestSupport.Catalog.Equipment")
        );
        assert!(plan.unit_created);
        assert!(!plan.projection);
        assert_eq!(
            labels(&plan.units),
            vec![
                "moduledoc",
                "alias Sportipedia.Catalog.Repo",
                "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel",
                "defs new_widget",
                "new_widgets/1",
            ]
        );
    }

    #[test]
    fn the_names_are_the_seed_pair_and_the_plural() {
        let ctx = ctx_for("widget");
        assert_eq!(Factory::seed_name(&ctx), "new_widget");
        assert_eq!(Factory::seed_all_name(&ctx), "new_widgets");
        assert_eq!(
            Factory::module_file(&ctx),
            "services/api/test/support/catalog/equipment/equipment.ex"
        );
        assert_eq!(
            Factory::module_name(&ctx),
            "Sportipedia.TestSupport.Catalog.Equipment"
        );
    }

    #[test]
    fn the_moduledoc_owns_the_ledger_words() {
        let units = units_for("widget");
        assert_eq!(
            render(&units, "moduledoc"),
            "@moduledoc \"\"\"\nTest-support factories for the equipment composite — they turn\nfixtures (or plain attribute maps) into persisted read models.\nGenerated `new_*` units append per read model; the file is a ledger.\n\"\"\""
        );
    }

    #[test]
    fn the_seed_pair_takes_the_struct_and_the_map() {
        let units = units_for("widget");
        assert_eq!(
            render(&units, "defs new_widget"),
            "@spec new_widget(WidgetReadModel.t() | map()) ::\n        {:ok, WidgetReadModel.t()} | {:error, Ecto.Changeset.t()}\ndef new_widget(%WidgetReadModel{} = fixture) do\n  new_widget(Map.from_struct(fixture))\nend\n\ndef new_widget(attributes) when is_map(attributes) do\n  %WidgetReadModel{}\n  |> WidgetReadModel.insert_changeset(attributes)\n  |> Repo.insert()\nend"
        );
    }

    #[test]
    fn the_plural_seed_fails_fast_on_a_bad_fixture() {
        let units = units_for("widget");
        assert_eq!(
            render(&units, "new_widgets/1"),
            "@spec new_widgets([WidgetReadModel.t() | map()]) :: [WidgetReadModel.t()]\ndef new_widgets(attribute_collection) do\n  Enum.map(attribute_collection, fn attributes ->\n    case new_widget(attributes) do\n      {:ok, widget} -> widget\n      {:error, changeset} ->\n        raise \"seeding widget fixture failed: #{inspect(changeset.errors)}\"\n    end\n  end)\nend"
        );
    }

    #[test]
    fn the_read_model_units_wait_for_the_read_model() {
        let units = units_for("widget");
        assert!(
            unit(&units, "alias Sportipedia.Catalog.Repo")
                .requires
                .is_empty()
        );
        let gate = vec![(
            "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex".to_string(),
            "the widget read model does not exist (sparch read_model)".to_string(),
        )];
        assert_eq!(
            unit(
                &units,
                "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel",
            )
            .requires,
            gate
        );
        assert_eq!(unit(&units, "defs new_widget").requires, gate);
        assert_eq!(unit(&units, "new_widgets/1").requires, gate);
    }

    #[test]
    fn the_struct_clause_check_reads_the_head_not_the_map_clause() {
        let map_only = ElixirFile::parse(
            "defmodule F do\n  def new_widget(attributes) when is_map(attributes) do\n    Repo.insert()\n  end\nend\n",
        );
        let both = ElixirFile::parse(
            "defmodule F do\n  def new_widget(%WidgetReadModel{} = fixture) do\n    new_widget(Map.from_struct(fixture))\n  end\n\n  def new_widget(attributes) when is_map(attributes) do\n    Repo.insert()\n  end\nend\n",
        );
        let units = units_for("widget");
        let pair = unit(&units, "defs new_widget");
        assert!(
            !(pair.check)(&map_only),
            "the struct clause is what makes it present"
        );
        assert!((pair.check)(&both));

        let stale = pair
            .stale
            .as_ref()
            .expect("the seed pair carries a stale check");
        let details = stale(&map_only);
        assert_eq!(
            details,
            vec![
                "new_widget/1 has no fixture-struct clause — add `def new_widget(%WidgetReadModel{} = fixture), do: new_widget(Map.from_struct(fixture))`".to_string()
            ]
        );
        assert!(stale(&both).is_empty());

        let empty = ElixirFile::parse("defmodule F do\nend\n");
        assert!(
            stale(&empty).is_empty(),
            "nothing standing yet means the clause is placed, not reported"
        );
    }

    #[test]
    fn the_plural_lands_after_the_singular_clause_group() {
        let units = units_for("widget");
        let pair = unit(&units, "defs new_widget");
        assert!(matches!(pair.place, Placement::BodyEnd));
        let all = unit(&units, "new_widgets/1");
        assert!(matches!(
            all.place,
            Placement::AfterDef { ref name, arity: 1 } if name == "new_widget"
        ));
    }

    #[test]
    fn the_factory_generates_without_examples_and_never_sweeps() {
        let bare = sparch_model::Element {
            doc: serde_json::json!({
                "apiVersion": "schema.esdm.io/core/v1",
                "kind": "read-model",
                "name": "widget",
            }),
            ..ctx_for("widget").element.clone()
        };
        let ctx = ctx_for("widget").with_element(&bare);
        assert_eq!(Factory.plans(&ctx).len(), 1, "shape needs no examples");
        assert_eq!(Factory.name(), "factory");
        assert_eq!(Factory.source_kinds(), vec![ElementKind::ReadModel]);
        assert_eq!(Factory.closure_scope(), ClosureScope::None);
        let deps = Factory.dependencies(&ctx);
        assert_eq!(deps.len(), 1);
        assert_eq!(deps[0].blueprint_name, "read_model");
    }
}
