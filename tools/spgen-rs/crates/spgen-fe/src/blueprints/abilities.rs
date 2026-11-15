//! `abilities` — one predicate per command, fully derived from the
//! command's `actors:` list plus the standing admin rule. Policy here is
//! data, not logic.

use spgen_model::Citizen;

use super::{Output, declaration, import, jsdoc, out};
use crate::{layout::Layout, plan::FilePlan};

pub fn plan(citizen: &Citizen, layout: &Layout) -> Output {
    if citizen.commands.is_empty() {
        return out(vec![]);
    }

    let mut units = vec![];
    let mut body = String::new();
    let mut notes = vec![];

    for command in &citizen.commands {
        if command.effect.as_deref() == Some("none") && command.data_fields.is_empty() {
            notes.push(format!(
                "command {} declares effect none — ability still generated; verify the verb",
                command.name
            ));
        }
        let mut unit = render(citizen, command);
        // the imports the predicate needs ride with it
        unit = unit.with(import("@sportipedia/user", true, "User"));
        if matches!(
            command.effect.as_deref(),
            Some("update") | Some("delete") | Some("none")
        ) {
            unit = unit.with(import(
                &format!("./{}", citizen.constituent),
                true,
                &citizen.type_name,
            ));
        }
        body.push_str(&unit.text);
        body.push('\n');
        units.push(unit);
    }

    out(vec![FilePlan {
        path: layout.abilities(),
        host: false,
        create: Some(create(citizen, &body)),
        units,
    }])
}

pub fn ability_name(command: &spgen_model::citizen::Command) -> String {
    format!("can{}", command.pascal)
}

fn render(citizen: &Citizen, command: &spgen_model::citizen::Command) -> super::Unit {
    let head = jsdoc(&[
        &format!("@group {}", citizen.type_name),
        "@category Abilities",
        "@source",
    ]);
    let predicate = command
        .roles
        .iter()
        .map(|role| format!("user?.role === '{role}'"))
        .collect::<Vec<_>>()
        .join(" || ");
    let takes_record = matches!(
        command.effect.as_deref(),
        Some("update") | Some("delete") | Some("none")
    );
    let signature = if takes_record {
        format!(
            "export function {}(_{}: {}, user?: User) {{",
            ability_name(command),
            citizen.constituent,
            citizen.type_name
        )
    } else {
        format!("export function {}(user?: User) {{", ability_name(command))
    };
    declaration(
        &ability_name(command),
        format!("{head}{signature}\n  return {predicate};\n}}\n"),
    )
}

fn create(citizen: &Citizen, body: &str) -> String {
    let mut text = jsdoc(&[
        &format!("@module {} Abilities", citizen.type_name),
        &format!("@mergeModuleWith {}", citizen.type_name),
    ]);
    text.push('\n');
    text.push_str(&format!(
        "import type {{ {} }} from './{}';\n",
        citizen.type_name, citizen.constituent
    ));
    text.push_str("import type { User } from '@sportipedia/user';\n\n");
    text.push_str(body);
    text
}
