//! The command's contribution to the operation test file — ported from
//! `SpGen.Blueprint.CommandTest`
//! (`tools/spgen/lib/sp_gen/blueprint/command_test.ex`).
//!
//! A `describe "Command"` block validating the struct's enforced fields:
//! `requires id` always, `id cannot be nil` when a validator looks the id
//! up (the test pins that the lookup never runs on an absent id), and
//! `validates presence of <field>` for every required field the model
//! states.

use crate::blueprints::command::Command;
use crate::blueprints::test_case::{self, Describe, Options};
use crate::context::Context;
use crate::plan::{Blueprint, FilePlan};
use crate::templates;
use spgen_model::ElementKind;
use spgen_model::invariants::ValidatorKind;

const TEST_PATH: &str = "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operations/<_operation>_test.exs";
const TEST_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Command>Test";

pub struct CommandTest;

impl Blueprint for CommandTest {
    fn name(&self) -> &'static str {
        "command_test"
    }

    /// The oracle derives its sweep participation from the generator's
    /// head (`primary.accepts?`); the Rust sweep asks each ported module,
    /// so the companion names the kind it contributes to.
    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(TEST_PATH, "enforced field validation tests")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        vec![test_case::plan(
            ctx,
            Options {
                path_template: TEST_PATH,
                module_template: TEST_MODULE,
                extra_vars: Default::default(),
                alias_templates: vec![Command::module_template()],
                alias_modules: Vec::new(),
                requires: vec![(
                    Command::module_file(ctx),
                    "command not generated (spgen command)".to_string(),
                )],
                alias_requires: None,
                describes: vec![Describe {
                    subject_template: "Command",
                    body: Box::new(describe_body),
                    alternates: vec!["<Command> command"],
                }],
            },
        )]
    }
}

/// The `describe` body — `CommandTest.describe_body/2`, heredoc whitespace
/// included.
pub fn describe_body(ctx: &Context, subject: &str) -> String {
    let cmd = ctx.render_or_panic("<Command>");

    // the nil-id test is meaningful only when a validator looks the id up:
    // it pins that the lookup never runs on an absent id — `presence` alone
    // answers, and a 500 raise is what the unguarded shape used to answer
    let mut tests = vec![requires_id_test(&cmd)];
    if exists_by_id(ctx) {
        tests.extend(id_nil_test(ctx, &cmd));
    }
    tests.extend(presence_tests(ctx, &cmd));

    format!(
        "describe \"{subject}\" do\n{}\nend",
        templates::indent(&tests.join("\n\n"), 2)
    )
}

fn requires_id_test(cmd: &str) -> String {
    format!(
        "test \"requires id\" do\n  assert_raise ArgumentError, fn ->\n    struct!({cmd}, %{{}})\n  end\nend"
    )
}

// every enforced field must be present; only the id is nil
fn id_nil_test(ctx: &Context, cmd: &str) -> Vec<String> {
    let body = ctx
        .fields
        .iter()
        .filter(|f| f.name != "id")
        .map(|f| format!("{}: {}", f.name, templates::sample_value(ctx, f)))
        .collect::<Vec<_>>()
        .join(", ");
    let literal = if body.is_empty() {
        "id: nil".to_string()
    } else {
        format!("{body}, id: nil")
    };

    vec![format!(
        "test \"id cannot be nil\" do\n  cmd = %{cmd}{{{literal}}}\n\n  # Rejected, not raised: the existence check used to hand the nil to\n  # `Repo.get/2`, which raises, and the command never got to answer.\n  # `allow_blank` on the `validates` line keeps the lookup off an absent\n  # address, so `presence` is the only rule that speaks for the id.\n  assert [:presence] ==\n           cmd\n           |> Vex.errors()\n           |> Enum.flat_map(fn {{_error, field, rule, _message}} ->\n             if field == :id, do: [rule], else: []\n           end)\nend"
    )]
}

fn exists_by_id(ctx: &Context) -> bool {
    ctx.validators
        .iter()
        .any(|v| v.kind == ValidatorKind::Exists && v.field == "id")
}

fn presence_tests(ctx: &Context, cmd: &str) -> Vec<String> {
    ctx.fields
        .iter()
        .filter(|f| f.required && f.name != "id")
        .map(|f| {
            let excluded = f.name.clone();
            let body = ctx
                .fields
                .iter()
                .filter(|x| x.name != excluded)
                .map(|x| format!("{}: {}", x.name, templates::sample_value(ctx, x)))
                .collect::<Vec<_>>()
                .join(", ");
            format!(
                "test \"validates presence of {name}\" do\n  cmd = %{cmd}{{{body}, {name}: nil}}\n\n  assert {{:error, _errors}} = Vex.validate(cmd)\nend",
                name = f.name
            )
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use spgen_model::Model;
    use std::path::PathBuf;

    fn ctx_for(name: &str) -> Context {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model
            .resolve(name, &[ElementKind::Command])
            .expect("fixture command");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn plan(name: &str) -> FilePlan {
        CommandTest.plans(&ctx_for(name)).remove(0)
    }

    #[test]
    fn the_test_file_plan_lands_alias_and_describe_behind_the_command_gate() {
        let plan = plan("create-widget");
        assert_eq!(
            plan.path,
            "services/api/test/sportipedia/catalog/equipment/widget/operations/create_widget_test.exs"
        );
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.Catalog.Equipment.Widget.Operation.CreateWidgetTest")
        );
        assert!(plan.requires_describe);
        let ids: Vec<String> = plan.units.iter().map(|u| u.id.label()).collect();
        assert_eq!(
            ids,
            vec![
                "use Sportipedia.CatalogTestCase",
                "moduletag",
                "test_alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget",
                "describe Command",
            ]
        );
        // aliases and describes carry the command-module gate
        for unit in &plan.units[2..] {
            assert_eq!(
                unit.requires,
                vec![(
                    "services/api/lib/sportipedia/catalog/equipment/widget/operations/create_widget/command.ex"
                        .to_string(),
                    "command not generated (spgen command)".to_string(),
                )],
                "{}",
                unit.id.label()
            );
        }
    }

    #[test]
    fn the_create_shape_tests_presence_of_every_required_field() {
        let ctx = ctx_for("create-widget");
        let body = describe_body(&ctx, "Command");
        assert!(
            body.starts_with("describe \"Command\" do\n  test \"requires id\" do\n"),
            "{body}"
        );
        assert!(
            body.contains("struct!(CreateWidget, %{})"),
            "the enforced-id raise:\n{body}"
        );
        assert!(
            body.contains("test \"validates presence of title\" do"),
            "{body}"
        );
        assert!(
            body.contains("test \"validates presence of slug\" do"),
            "{body}"
        );
        assert!(
            !body.contains("id cannot be nil"),
            "no validator looks the create id up:\n{body}"
        );
    }

    #[test]
    fn the_delete_shape_pins_the_nil_id() {
        let ctx = ctx_for("archive-widget");
        let body = describe_body(&ctx, "Command");
        assert!(body.contains("cmd = %ArchiveWidget{id: nil}"), "{body}");
        assert!(
            body.contains("assert [:presence] =="),
            "the lookup must never see the nil:\n{body}"
        );
        assert!(body.ends_with("end\nend"), "heredoc shape:\n{body}");
    }

    #[test]
    fn the_none_shape_fills_every_field_but_the_nil_one() {
        let ctx = ctx_for("note-widget");
        let body = describe_body(&ctx, "Command");
        assert!(
            body.contains("cmd = %NoteWidget{comment: \"sample-comment\", id: nil}"),
            "{body}"
        );
        assert!(
            body.contains(
                "cmd = %NoteWidget{id: UUID.uuid5(:dns, \"equipment:widget:classic-widget\"), comment: nil}"
            ),
            "{body}"
        );
    }

    #[test]
    fn the_describe_check_accepts_the_alternate_spelling() {
        let units = plan("create-widget").units;
        let describe = units
            .iter()
            .find(|u| u.id.label() == "describe Command")
            .expect("the describe");
        let existing = crate::elixir::ElixirFile::parse(
            "defmodule T do\n  describe \"CreateWidget command\" do\n  end\nend\n",
        );
        assert!((describe.check)(&existing));
    }

    #[test]
    fn the_update_shape_states_the_partial_contract() {
        // edit-widget requires nothing: presence tests are absent, the
        // id-nil test is there (the exists validator looks the id up)
        let ctx = ctx_for("edit-widget");
        let body = describe_body(&ctx, "Command");
        assert!(body.contains("id cannot be nil"), "{body}");
        assert!(
            !body.contains("validates presence of"),
            "no required data field in the update shape:\n{body}"
        );
    }
}
