//! `ability-test` — the role truth table per ability, against the model's
//! actors and the user fixture roles. A test file appears only with a
//! test, and its units gate on the fixtures and roles they address.

use std::path::PathBuf;

use spgen_model::{Case, Citizen, Name};

use super::{Output, import, out, test_gated};
use crate::{blueprints::abilities::ability_name, layout::Layout, plan::FilePlan};

pub fn plan(citizen: &Citizen, layout: &Layout) -> Output {
    if citizen.commands.is_empty() {
        return out(vec![]);
    }

    let fixtures_file = layout.fixtures();
    let roles_file = PathBuf::from("apps")
        .join(&citizen.subdomain)
        .join("tests/user/support/fixtures/index.ts");
    let abilities_source = format!(
        "#/{}/domain-objects/{}/abilities",
        citizen.composite, citizen.constituent
    );

    let mut units = vec![];
    let mut body = String::new();

    for command in &citizen.commands {
        let ability = ability_name(command);

        let takes_record = matches!(
            command.effect.as_deref(),
            Some("update") | Some("delete") | Some("none")
        );
        let primary = if takes_record {
            match citizen.fixtures.first() {
                Some(fixture) => Some(fixture),
                None => continue, // no fixture yet — the table cannot address a record
            }
        } else {
            None
        };

        let mut block = format!("test('{ability}()', () => {{\n");
        for role in &citizen.roles {
            let role_const = Name::parse(role).render(Case::Screaming);
            let args = match primary {
                Some(fixture) => format!("{}, {}", fixture.const_name, role_const),
                None => role_const,
            };
            let expect = if command.roles.iter().any(|r| r == role) {
                "toBeTruthy"
            } else {
                "toBeFalsy"
            };
            block.push_str(&format!("  expect({ability}({args})).{expect}();\n"));
        }
        block.push_str("});\n");

        let mut gates = vec![roles_file.clone()];
        if takes_record {
            gates.push(fixtures_file.clone());
        }
        let mut unit = test_gated(&format!("{ability}()"), block, gates);
        unit.id = format!("test('{}()')", ability);
        // the imports the truth table needs ride with the test
        unit = unit
            .with(import("vitest", false, "expect"))
            .with(import("vitest", false, "test"))
            .with(import(&abilities_source, false, &ability));
        if let Some(fixture) = primary {
            unit = unit.with(import(
                &Layout::test_support_alias(&citizen.composite),
                false,
                &fixture.const_name,
            ));
        }
        for role in &citizen.roles {
            let role_const = Name::parse(role).render(Case::Screaming);
            unit = unit.with(import("#tests/user/support/fixtures", false, &role_const));
        }
        body.push_str(&unit.text);
        body.push('\n');
        units.push(unit);
    }

    if body.is_empty() {
        return out(vec![]);
    }

    out(vec![FilePlan {
        path: layout.ability_test(),
        host: false,
        create: Some(create(citizen, &body)),
        units,
    }])
}

fn create(citizen: &Citizen, body: &str) -> String {
    let mut abilities: Vec<String> = citizen
        .commands
        .iter()
        .map(|c| format!("  {}", ability_name(c)))
        .collect();
    abilities.sort();

    let mut text = String::from("import { expect, test } from 'vitest';\n\n");
    text.push_str(&format!(
        "import {{\n{}\n}} from '#/{}/domain-objects/{}/abilities';\n",
        abilities.join(",\n").trim_end_matches(','),
        citizen.composite,
        citizen.constituent
    ));
    if let Some(primary) = citizen.fixtures.first() {
        text.push_str(&format!(
            "import {{ {} }} from '{}';\n",
            primary.const_name,
            Layout::test_support_alias(&citizen.composite)
        ));
    }
    let mut roles: Vec<String> = citizen
        .roles
        .iter()
        .map(|r| Name::parse(r).render(Case::Screaming))
        .collect();
    roles.sort();
    text.push_str(&format!(
        "import {{ {} }} from '#tests/user/support/fixtures';\n",
        roles.join(", ")
    ));
    text.push('\n');
    text.push_str(body);
    text
}
