//! The event struct file — the executable transfer of
//! `docs/architecture/blueprints/backend/domain/event.md`, ported from
//! `SpGen.Blueprint.Event` (`tools/spgen/lib/sp_gen/blueprint/event.ex`).
//!
//! Templates follow what the operation does:
//!
//! * `--template create` — full facts, all required fields enforced
//! * `--template update` — id enforced, payload partial; a `get_changes/1`
//!   function accompanies the struct (the projector's partial-update source)
//! * `--template delete` — id-only fact
//! * `--template none` — no materialization decision; the plain fact

use crate::context::{Context, Operation};
use crate::elixir::Rank;
use crate::plan::{Blueprint, FilePlan, Placement, Unit, UnitId};
use crate::templates;

const PATH: &str =
    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/events/<_event>.ex";
const MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>";

pub struct Event;

impl Event {
    /// The event's module-name template (referenced by `EventTest`).
    pub fn module_template() -> &'static str {
        MODULE
    }

    /// The event module's file path for the element in `ctx` (used as a
    /// `requires` gate) — `Event.module_file/1`.
    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(PATH)
    }
}

impl Blueprint for Event {
    fn name(&self) -> &'static str {
        "event"
    }

    fn description(&self) -> Option<&'static str> {
        Some("Generates an event module and its test describe block")
    }

    fn source_kinds(&self) -> Vec<sparch_model::ElementKind> {
        vec![sparch_model::ElementKind::Event]
    }

    fn is_fixed(&self) -> bool {
        false
    }

    fn operations(&self) -> Vec<Operation> {
        vec![
            Operation::Create,
            Operation::Update,
            Operation::Delete,
            Operation::None,
        ]
    }

    fn optional_template(&self) -> bool {
        true
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(PATH, "typedstruct fact with enforces")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        vec![FilePlan::new(
            ctx.render_or_panic(PATH),
            Some(ctx.render_or_panic(MODULE)),
            units(ctx),
        )]
    }
}

// ------------------------------------------------------------------- units

fn units(ctx: &Context) -> Vec<Unit> {
    let mut units: Vec<Unit> = Vec::new();

    // @moduledoc — the prose slot keeps the blueprint's own wording until
    // the model carries a description.
    {
        let doc = ctx.render_or_panic(
            "<Describe what happened in the domain, derived from the event name.>",
        );
        units.push(Unit {
            id: UnitId::Moduledoc,
            check: Box::new(|f| f.has_moduledoc()),
            render: Box::new(move || format!("@moduledoc \"\"\"\n{doc}\n\"\"\"")),
            place: Placement::Head {
                rank: Rank::Moduledoc,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        });
    }

    units.push(use_unit("TypedStruct"));
    units.push(use_unit("ExConstructor"));

    // @derive Jason.Encoder
    units.push(Unit {
        id: UnitId::Derive("Jason.Encoder".into()),
        check: Box::new(|f| f.attr_names("derive", "Jason.Encoder")),
        render: Box::new(|| "@derive Jason.Encoder".to_string()),
        place: Placement::Head {
            rank: Rank::Attribute,
            alias_sort_key: None,
        },
        requires: Vec::new(),
        stale: None,
    });

    // fields inside typedstruct
    for f in &ctx.fields {
        let key = format!(":{}", f.name);
        let render = templates::field_line(f);
        units.push(Unit {
            id: UnitId::Field(f.name.clone()),
            check: Box::new(move |file| file.has_entry("field", &key)),
            render: Box::new(move || render.clone()),
            place: Placement::Inside {
                macro_name: "typedstruct".into(),
                wrapper: Some("typedstruct do\n{unit}\nend".into()),
                before_trailing: None,
            },
            requires: Vec::new(),
            stale: None,
        });
    }

    units.extend(changes_units(ctx));
    units
}

fn use_unit(module: &str) -> Unit {
    let render = format!("use {module}");
    let check_module = module.to_string();
    Unit {
        id: UnitId::Use(module.to_string()),
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

// `get_changes/1` exists for the partial-update contract — a projector
// merging changes onto a row. It is generated for exactly the `update`
// declaration: never for `create`, `delete`, the declared `none`, and never
// for an event nobody declared.
fn changes_units(ctx: &Context) -> Vec<Unit> {
    if ctx.operation != Some(Operation::Update) {
        return Vec::new();
    }
    vec![Unit {
        id: UnitId::Def("get_changes".into(), 1),
        check: Box::new(|f| f.has_def("get_changes", 1)),
        render: Box::new(|| {
            "@doc \"\"\"\nReturns a map of only the non-nil changed fields (excluding id).\n\"\"\"\n@spec get_changes(t()) :: map()\ndef get_changes(%__MODULE__{} = event) do\n  event\n  |> Map.from_struct()\n  |> Map.drop([:id])\n  |> Enum.reject(fn {_k, v} -> is_nil(v) end)\n  |> Map.new()\nend"
                .to_string()
        }),
        place: Placement::BodyEnd,
        requires: Vec::new(),
        stale: None,
    }]
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use sparch_model::Model;
    use std::path::PathBuf;

    fn ctx_for(event: &str) -> Context {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model
            .resolve(event, &[sparch_model::ElementKind::Event])
            .expect("fixture event");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    #[test]
    fn paths_and_modules_render_like_the_oracle() {
        let ctx = ctx_for("widget-created");
        assert_eq!(
            Event::module_file(&ctx),
            "services/api/lib/sportipedia/catalog/equipment/widget/events/widget_created.ex"
        );
        assert_eq!(
            ctx.render_or_panic(Event::module_template()),
            "Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated"
        );
    }

    #[test]
    fn unit_ids_and_order_mirror_the_oracle() {
        let ctx = ctx_for("widget-created");
        let plans = Event.plans(&ctx);
        let ids: Vec<String> = plans[0].units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            ids,
            vec![
                "moduledoc",
                "use TypedStruct",
                "use ExConstructor",
                "derive Jason.Encoder",
                "field id",
                "field title",
                "field slug",
                "field coachId",
                "field description",
                "field label",
                "field teamId",
            ]
        );
    }

    #[test]
    fn get_changes_exists_only_for_the_update_shape() {
        // widget-edited declares `spgen.operation.widget-edited: update`
        let updated = ctx_for("widget-edited");
        assert_eq!(updated.operation, Some(Operation::Update));
        assert!(
            Event.plans(&updated)[0]
                .units
                .iter()
                .any(|u| u.id.label() == "get_changes/1")
        );

        // create, delete and the declared `none` never carry it
        for event in ["widget-created", "widget-archived", "widget-noted"] {
            let ctx = ctx_for(event);
            assert!(
                !Event.plans(&ctx)[0]
                    .units
                    .iter()
                    .any(|u| u.id.label() == "get_changes/1"),
                "{event} must not carry get_changes/1"
            );
        }
    }

    #[test]
    fn renders_carry_the_exact_oracle_text() {
        let ctx = ctx_for("widget-created");
        let units = Event.plans(&ctx)[0].units.clone_unit_texts();
        assert_eq!(
            units["moduledoc"],
            "@moduledoc \"\"\"\nA widget was cataloged\n\"\"\""
        );
        assert_eq!(units["derive Jason.Encoder"], "@derive Jason.Encoder");
        assert_eq!(units["field id"], "field :id, String.t(), enforce: true");
        assert_eq!(units["field label"], "field :label, String.t()");
    }

    #[test]
    fn update_shape_renders_get_changes_verbatim() {
        let ctx = ctx_for("widget-edited");
        let units = Event.plans(&ctx)[0].units.clone_unit_texts();
        assert_eq!(
            units["get_changes/1"],
            "@doc \"\"\"\nReturns a map of only the non-nil changed fields (excluding id).\n\"\"\"\n@spec get_changes(t()) :: map()\ndef get_changes(%__MODULE__{} = event) do\n  event\n  |> Map.from_struct()\n  |> Map.drop([:id])\n  |> Enum.reject(fn {_k, v} -> is_nil(v) end)\n  |> Map.new()\nend"
        );
    }

    // test helper: unit texts keyed by label (the units hold closures)
    trait UnitTexts {
        fn clone_unit_texts(&self) -> std::collections::HashMap<String, String>;
    }
    impl UnitTexts for [Unit] {
        fn clone_unit_texts(&self) -> std::collections::HashMap<String, String> {
            self.iter().map(|u| (u.id.label(), (u.render)())).collect()
        }
    }
}
