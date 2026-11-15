//! `fixtures` — one frozen const per read-model example, the collection
//! const, and the find helpers. A reference in an example resolves to the
//! named const of the referenced citizen's fixtures file — that file is
//! the gate: while it is missing, the const defers and back-fills the day
//! its subject appears.

use std::path::PathBuf;

use spgen_model::{Case, Citizen, Name, fixtures::parse_key};

use super::{Output, declaration, import, member, out};
use crate::{layout::Layout, plan::FilePlan};

pub fn plan(citizen: &Citizen, layout: &Layout) -> Output {
    if citizen.fixtures.is_empty() {
        return out(vec![]);
    }

    let plural = Name::parse(&citizen.constituent).plural_kebab();
    let collection = Name::parse(&citizen.constituent).render_plural(Case::Screaming);
    let anchor = format!("export const {collection} = [");

    let mut units = vec![];
    let mut consts = String::new();

    for fixture in &citizen.fixtures {
        let text = render_const(citizen, fixture);
        let mut gates: Vec<PathBuf> = Vec::new();
        let mut ref_units = vec![];

        for entry in &fixture.entries {
            if let spgen_model::FixtureEntry::Reference {
                target_const,
                target_composite,
                target_key,
                ..
            } = entry
            {
                gates.push(target_fixture_file(
                    &citizen.subdomain,
                    target_composite,
                    target_key,
                ));
                ref_units.push(import(
                    &Layout::test_support_alias(target_composite),
                    false,
                    target_const,
                ));
            }
        }

        consts.push_str(&text);
        consts.push('\n');
        let mut unit = declaration(&fixture.const_name, text);
        unit.gate = gates;
        for import_unit in ref_units {
            unit = unit.with(import_unit);
        }
        units.push(unit);
        units.push(member(&anchor, &fixture.const_name));
    }

    // collection const + find helpers
    let collection_text = collection_const(citizen, &collection);
    units.push(declaration(&collection, collection_text.clone()));

    // finders are projections of real properties — a parameter that no
    // property backs simply cannot be constructed
    let finder_units = finders(citizen, &collection);
    let mut names = vec![collection.clone()];
    for unit in &finder_units {
        names.push(unit.id.clone());
    }
    units.extend(finder_units);

    // the test-support barrel: this artifact's block, gated on the
    // fixture files it can actually export — while any referenced
    // composite is missing, the fixtures file (and with it the barrel)
    // defers as a unit
    let source = format!("./fixtures/{plural}");
    let mut block_names: Vec<String> = citizen
        .fixtures
        .iter()
        .map(|f| f.const_name.clone())
        .collect();
    block_names.extend(names);
    block_names.sort();

    let mut barrel_gate: Vec<std::path::PathBuf> = Vec::new();
    for unit in &units {
        for g in &unit.gate {
            if !barrel_gate.contains(g) {
                barrel_gate.push(g.clone());
            }
        }
    }

    let mut output = out(vec![
        FilePlan {
            path: layout.fixtures(),
            host: false,
            create: Some(create(citizen, &consts, &collection)),
            units,
        },
        super::barrel_plan(layout, &source, &block_names, barrel_gate),
    ]);
    if citizen.lookup.is_none() {
        output.notes.push(format!(
            "read-model {} declares no read query with parameters.oneOf — fixture finders fall back to id",
            citizen.constituent
        ));
    }
    output
}

/// `apps/catalog/tests/<composite>/support/fixtures/<plural of the target
/// read model>.ts` — the file that must define the referenced const.
fn target_fixture_file(subdomain: &str, composite: &str, key: &str) -> PathBuf {
    let read_model = parse_key(key)
        .map(|(_, rm, _)| rm)
        .unwrap_or_else(|_| composite.to_string());
    PathBuf::from("apps")
        .join(subdomain)
        .join("tests")
        .join(composite)
        .join("support/fixtures")
        .join(format!("{}.ts", Name::parse(&read_model).plural_kebab()))
}

fn render_const(citizen: &Citizen, fixture: &spgen_model::FixtureView) -> String {
    let mut text = format!(
        "export const {}: {} = Object.freeze({{\n  [Type]: '{}',\n",
        fixture.const_name, citizen.type_name, citizen.constituent
    );
    for entry in &fixture.entries {
        match entry {
            spgen_model::FixtureEntry::Identifier { ts_name, key } => {
                text.push_str(&format!("  {ts_name}: '{key}',\n"));
            }
            spgen_model::FixtureEntry::Attribute { ts_name, ts_value } => {
                text.push_str(&format!("  {ts_name}: {ts_value},\n"));
            }
            spgen_model::FixtureEntry::Reference {
                ts_name,
                target_const,
                ..
            } => {
                text.push_str(&format!("  {ts_name}: {target_const},\n"));
            }
        }
    }
    text.push_str("  createdAt: Temporal.Now.plainDateTimeISO(),\n");
    text.push_str("  updatedAt: Temporal.Now.plainDateTimeISO()\n");
    text.push_str("});\n");
    text
}

fn collection_const(citizen: &Citizen, collection: &str) -> String {
    let names: Vec<String> = citizen
        .fixtures
        .iter()
        .map(|f| f.const_name.clone())
        .collect();
    format!(
        "\nexport const {collection} = [\n  {}\n];\n",
        names.join(",\n  ")
    )
}

/// The finder units: one per **declared** addressing param (the read
/// queries' `oneOf`) — a finder over an undeclared field (like a storage
/// `raw_slug`) is not generated. Each finder's parameter, type, predicate
/// and type-import come from the same `Property`.
fn finders(citizen: &Citizen, collection: &str) -> Vec<super::Unit> {
    let plural_arg =
        Name::parse(&Name::parse(&citizen.constituent).plural_kebab()).render(Case::Camel);
    let params: Vec<String> = match &citizen.lookup {
        Some(lookup) => lookup.params.clone(),
        None => vec!["id".to_string()],
    };
    let props: Vec<&spgen_model::Property> = params
        .iter()
        .filter_map(|p| citizen.properties.iter().find(|pr| &pr.ts_name == p))
        .collect();

    props
        .iter()
        .map(|p| {
            let by = Name::parse(&p.ts_name).render(Case::Pascal);
            let name = format!("find{}By{}", citizen.type_name, by);
            let text = format!(
                concat!(
                    "\nexport function {name}(\n",
                    "  {param}: {param_type},\n",
                    "  {plural_arg}: {type}[] = {collection}\n",
                    "): {type} | undefined {{\n",
                    "  return {plural_arg}.find((i) => i.{param} === {param});\n}}\n"
                ),
                name = name,
                param = p.ts_name,
                param_type = p.ts_type,
                plural_arg = plural_arg,
                type = citizen.type_name,
                collection = collection,
            );
            super::declaration(&name, text).with(super::import(
                "#/support/domain-objects/fields",
                true,
                &p.ts_type,
            ))
        })
        .collect()
}

fn create(citizen: &Citizen, consts: &str, collection: &str) -> String {
    let mut text = String::from("import { Type } from '@warp-drive/core/types/symbols';\n");

    // imports of referenced consts, grouped by composite
    let mut refs: Vec<(String, Vec<String>)> = Vec::new();
    for fixture in &citizen.fixtures {
        for entry in &fixture.entries {
            if let spgen_model::FixtureEntry::Reference {
                target_const,
                target_composite,
                ..
            } = entry
            {
                match refs.iter_mut().find(|(c, _)| c == target_composite) {
                    Some((_, names)) if !names.contains(target_const) => {
                        names.push(target_const.clone())
                    }
                    Some(_) => {}
                    None => refs.push((target_composite.clone(), vec![target_const.clone()])),
                }
            }
        }
    }
    refs.sort();
    for (composite, mut names) in refs {
        names.sort();
        text.push_str(&format!(
            "\nimport {{ {} }} from '{}';\n",
            names.join(", "),
            Layout::test_support_alias(&composite)
        ));
    }

    let finder_units = finders(citizen, collection);

    // parameter types of the finders, imported from the fields module
    let mut finder_types: Vec<String> = finder_units
        .iter()
        .flat_map(|u| u.companions.iter().map(|c| c.text.clone()))
        .collect();
    finder_types.sort();
    finder_types.dedup();
    let fields_import = if finder_types.is_empty() {
        String::new()
    } else {
        format!(
            "import type {{ {} }} from '#/support/domain-objects/fields';\n",
            finder_types.join(", ")
        )
    };

    text.push_str(&format!(
        "\nimport type {{ {} }} from '{}';\n",
        citizen.type_name,
        Layout::barrel_alias(&citizen.composite)
    ));
    text.push_str(&fields_import);
    text.push('\n');
    text.push_str(consts);

    text.push_str(&collection_const(citizen, collection));
    for unit in &finder_units {
        text.push_str(&unit.text);
    }
    text
}
