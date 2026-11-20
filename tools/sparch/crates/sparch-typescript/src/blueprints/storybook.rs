//! `storybook` — per citizen: the field argTypes, the preset selector
//! control, the argTypes-with-preset wrapper, the args interface, the
//! from-args resolver, defaults, decorator and meta factory — appended
//! into the subdomain's shared `tests/<composite>/support/storybook.ts`.
//! Units gate on the fixtures they address (the selector's options and
//! the find helper).
//!
//! The selector argument is named with the citizen's own word (`position`,
//! `instrument`, …): it selects one existing fixture by slug, with the
//! `CUSTOM` sentinel for building one from the remaining args. Generators
//! never invent vocabulary — the model supplies the name.

use sparch_model::{Case, Citizen, Name};

use super::{Output, Unit, declaration, import, out};
use crate::{layout::Layout, plan::FilePlan};

pub fn plan(citizen: &Citizen, layout: &Layout) -> Output {
    let Some(primary) = citizen.fixtures.first() else {
        return out(vec![]);
    };
    let Some(lookup) = citizen.lookup.clone() else {
        let mut output = out(vec![]);
        output.notes.push(format!(
            "read-model {} declares no read query with parameters.oneOf — storybook needs declared addressing",
            citizen.constituent
        ));
        return output;
    };
    let preferred = lookup.preferred.clone();
    let preferred_pascal = Name::parse(&preferred).render(Case::Pascal);

    let fixtures_file = layout.fixtures();
    let mut gates = vec![fixtures_file.clone()];
    for property in citizen
        .properties
        .iter()
        .filter(|p| p.kind == sparch_model::PropertyKind::Reference)
    {
        let Some(relation) = &property.relation else {
            continue;
        };
        if relation.target_composite.is_empty() {
            continue;
        }
        gates.push(
            std::path::PathBuf::from("apps")
                .join(&citizen.subdomain)
                .join("tests")
                .join(&relation.target_composite)
                .join("support/fixtures")
                .join(format!(
                    "{}.ts",
                    Name::parse(&relation.target).plural_kebab()
                )),
        );
    }
    let gates = gates;
    let plural = Name::parse(&citizen.constituent).plural_kebab();

    let mut units = vec![];
    let mut body = String::new();

    // relationship collections and find helpers from the targets' barrels
    let mut rel_lists: Vec<Unit> = vec![];
    let mut rel_finds: Vec<Unit> = vec![];
    let mut seen: Vec<String> = Vec::new();
    for property in citizen
        .properties
        .iter()
        .filter(|p| p.kind == sparch_model::PropertyKind::Reference)
    {
        let Some(relation) = &property.relation else {
            continue;
        };
        if relation.target_composite.is_empty() || seen.contains(&relation.target) {
            continue;
        }
        seen.push(relation.target.clone());
        let barrel = Layout::test_support_alias(&relation.target_composite);
        rel_lists.push(import(
            &barrel,
            false,
            &Name::parse(&relation.target).render_plural(Case::Screaming),
        ));
        rel_finds.push(import(
            &barrel,
            false,
            &format!("find{}BySlug", relation.target_type),
        ));
    }

    let custom = || import("#tests/support/storybook.ts", false, "CUSTOM");
    let own_find = import(
        &format!("./fixtures/{plural}"),
        false,
        &format!("find{}By{}", citizen.type_name, preferred_pascal),
    );
    let primary_import = import(&format!("./fixtures/{plural}"), false, &primary.const_name);

    let mut argtypes_companions = vec![custom()];
    argtypes_companions.extend(rel_lists.clone());
    let mut fromargs_companions = vec![custom(), own_find];
    fromargs_companions.extend(rel_finds.clone());

    for (name, text, companions) in [
        (
            format!("make{}PresetControl", citizen.type_name),
            preset_control(citizen, &preferred),
            vec![custom()],
        ),
        (
            format!("make{}ArgTypes", citizen.type_name),
            field_arg_types(citizen),
            argtypes_companions,
        ),
        (
            format!("make{}ArgTypesWithPreset", citizen.type_name),
            arg_types_with_preset(citizen),
            vec![],
        ),
        (
            format!("{}Args", citizen.type_name),
            args_type(citizen),
            vec![],
        ),
        (
            format!("get{}FromArgs", citizen.type_name),
            from_args(citizen, &preferred_pascal),
            fromargs_companions,
        ),
        (
            format!("get{}DefaultArgs", citizen.type_name),
            default_args(citizen, &primary.const_name, &preferred),
            vec![primary_import],
        ),
        (
            format!("make{}Decorator", citizen.type_name),
            decorator(citizen),
            vec![],
        ),
        (
            format!("make{}Meta", citizen.type_name),
            meta(citizen),
            vec![],
        ),
    ] {
        let mut unit = declaration(&name, text);
        unit.gate = gates.clone();
        for companion in companions {
            unit = unit.with(companion);
        }
        body.push_str(&unit.text);
        body.push('\n');
        units.push(unit);
    }

    out(vec![
        FilePlan {
            path: layout.storybook(),
            host: false,
            create: Some(create(citizen, &body, &preferred, &preferred_pascal)),
            units,
        },
        barrel_plan(citizen, layout, &gates),
    ])
}

/// Names this artifact contributes to the test-support barrel block
/// (interface/type names carry the `type` marker).
pub fn barrel_names(citizen: &Citizen) -> Vec<String> {
    let mut names = vec![
        format!("make{}PresetControl", citizen.type_name),
        format!("make{}ArgTypes", citizen.type_name),
        format!("make{}ArgTypesWithPreset", citizen.type_name),
        format!("{}Args", citizen.type_name),
        format!("get{}FromArgs", citizen.type_name),
        format!("get{}DefaultArgs", citizen.type_name),
        format!("make{}Decorator", citizen.type_name),
        format!("make{}Meta", citizen.type_name),
    ];
    names.sort();
    names
}

pub fn barrel_member(name: &str) -> String {
    if name.chars().next().is_some_and(|c| c.is_ascii_uppercase()) {
        format!("type {name}")
    } else {
        name.to_string()
    }
}

/// The storybook block of the test-support barrel, gated like the
/// storybook file itself: while the fixtures it exports are not there,
/// neither is the block.
fn barrel_plan(citizen: &Citizen, layout: &Layout, gate: &[std::path::PathBuf]) -> FilePlan {
    let source = "./storybook";
    let members: Vec<String> = barrel_names(citizen)
        .iter()
        .map(|n| barrel_member(n))
        .collect();
    super::barrel_plan(layout, source, &members, gate.to_vec())
}

fn preset_control(citizen: &Citizen, preferred: &str) -> String {
    format!(
        concat!(
            "\nexport function make{type}PresetControl(collection: {type}[]): InputType {{\n",
            "  return {{\n    control: {{\n      type: 'select',\n      labels: {{\n",
            "        ...Object.fromEntries(collection.map((e) => [e.{preferred}, e.title]))\n      }}\n    }},\n",
            "    options: [CUSTOM, ...collection.map((i) => i.{preferred})]\n  }};\n}}\n"
        ),
        type = citizen.type_name,
        preferred = preferred,
    )
}

/// The data fields as Storybook argTypes — attributes, Slugs, and
/// relationship selects. Named by the citizen so a second citizen in the
/// same composite gets its own function, never a shared unsuffixed one.
fn field_arg_types(citizen: &Citizen) -> String {
    let mut text = format!(
        concat!(
            "\nexport function make{type}ArgTypes(options?: {{\n",
            "  category?: string;\n  subcategory?: string;\n  condition?: Conditional\n",
            "}}): Record<string, InputType> {{\n  const table = {{\n    category: 'Domain Object',\n",
            "    subcategory: '{type}',\n    ...options\n  }};\n",
            "  const condition = options?.condition ?? {{ arg: '{arg}', eq: CUSTOM }};\n\n  return {{\n"
        ),
        type = citizen.type_name,
        arg = citizen.constituent,
    );
    for property in &citizen.properties {
        match property.kind {
            sparch_model::PropertyKind::Identifier => continue,
            sparch_model::PropertyKind::Reference => {
                let options_const = property
                    .relation
                    .as_ref()
                    .map(|r| {
                        Name::parse(&r.target)
                            .render_plural(Case::Screaming)
                            .to_string()
                    })
                    .unwrap_or_default();
                text.push_str(&format!(
                    concat!(
                        "    {name}: {{\n      control: {{\n        type: 'select',\n        labels: {{\n",
                        "          ...Object.fromEntries({options}.map((e) => [e.slug, e.title]))\n        }}\n",
                        "      }},\n      options: {options},\n      if: condition,\n      table\n    }},\n"
                    ),
                    name = property.ts_name,
                    options = options_const,
                ));
            }
            _ => {
                let ts_name_type = match property.ts_type.as_str() {
                    "number" => "number",
                    "boolean" => "boolean",
                    _ => "string",
                };
                text.push_str(&format!(
                    "    {}: {{\n      type: {{ required: {}, name: '{}' }},\n      if: condition,\n      table\n    }},\n",
                    property.ts_name,
                    !property.optional,
                    ts_name_type
                ));
            }
        }
    }
    text.push_str("  };\n}\n");
    text
}

/// The wrapper: the citizen's preset selector entry over the field
/// argTypes. Stories that want the fixture dropdown take this; stories
/// that manage their own controls take `make{Type}ArgTypes` alone.
fn arg_types_with_preset(citizen: &Citizen) -> String {
    format!(
        concat!(
            "\nexport function make{type}ArgTypesWithPreset(\n  collection: {type}[],\n",
            "  options?: {{\n    category?: string;\n    subcategory?: string;\n    condition?: Conditional\n  }}\n",
            "): Record<string, InputType> {{\n  return {{\n    {c}: {{\n",
            "      ...make{type}PresetControl(collection),\n",
            "      table: {{ category: options?.category ?? 'Domain Object' }}\n    }},\n",
            "    ...make{type}ArgTypes(options)\n  }};\n}}\n"
        ),
        type = citizen.type_name,
        c = citizen.constituent,
    )
}

fn args_type(citizen: &Citizen) -> String {
    let mut text = format!(
        "\nexport interface {}Args {{\n  {}: string;\n",
        citizen.type_name, citizen.constituent
    );
    for property in &citizen.properties {
        if property.kind == sparch_model::PropertyKind::Identifier {
            continue;
        }
        if property.kind == sparch_model::PropertyKind::Reference {
            // the select's value is the target's slug — a string in the
            // args, resolved to the domain object in `fromArgs`
            let mark = if property.optional { "?" } else { "" };
            text.push_str(&format!("  {}{mark}: string;\n", property.ts_name));
            continue;
        }
        let ts = match property.ts_type.as_str() {
            "number" => "number",
            "boolean" => "boolean",
            _ => "string",
        };
        let mark = if property.optional { "?" } else { "" };
        text.push_str(&format!("  {}{mark}: {ts};\n", property.ts_name));
    }
    text.push_str("}\n");
    text
}

fn from_args(citizen: &Citizen, preferred_pascal: &str) -> String {
    let mut literal = String::new();
    for property in &citizen.properties {
        if property.kind == sparch_model::PropertyKind::Identifier {
            continue;
        }
        if property.kind == sparch_model::PropertyKind::Reference {
            // the slug string resolves to the domain object — the FE
            // counterpart of the BE's id reference
            let find = format!(
                "find{}BySlug",
                property
                    .relation
                    .as_ref()
                    .map(|r| r.target_type.clone())
                    .unwrap_or_default()
            );
            literal.push_str(&format!(
                "      {}: args.{} ? {find}(args.{}) : undefined,\n",
                property.ts_name, property.ts_name, property.ts_name
            ));
            continue;
        }
        literal.push_str(&format!(
            "      {}: args.{},\n",
            property.ts_name, property.ts_name
        ));
    }
    format!(
        concat!(
            "\nexport function get{type}FromArgs(args: {type}Args, collection: {type}[]): {type} {{\n",
            "  return args.{c} === CUSTOM\n    ? {{\n      [Type]: '{constituent}',\n{id_line}",
            "{literal}      createdAt: Temporal.Now.plainDateTimeISO(),\n",
            "      updatedAt: Temporal.Now.plainDateTimeISO()\n    }}\n",
            "    : (find{type}By{preferred}(args.{c}, collection) as {type});\n}}\n"
        ),
        type = citizen.type_name,
        c = citizen.constituent,
        constituent = citizen.constituent,
        id_line = "      id: args.slug,\n",
        literal = literal,
        preferred = preferred_pascal,
    )
}

fn default_args(citizen: &Citizen, primary: &str, preferred: &str) -> String {
    let mut fields = String::new();
    for property in &citizen.properties {
        if property.kind == sparch_model::PropertyKind::Identifier {
            continue;
        }
        if property.kind == sparch_model::PropertyKind::Reference {
            // the domain object contributes its slug to the args
            fields.push_str(&format!(
                "    {}: {}.{}?.slug,\n",
                property.ts_name, citizen.constituent, property.ts_name
            ));
            continue;
        }
        fields.push_str(&format!(
            "    {}: {}.{},\n",
            property.ts_name, citizen.constituent, property.ts_name
        ));
    }
    format!(
        concat!(
            "\nexport function get{type}DefaultArgs({c}: {type} = {primary}) {{\n  return {{\n",
            "    {c}: {c}.{preferred},\n{fields}  }};\n}}\n"
        ),
        type = citizen.type_name,
        c = citizen.constituent,
        primary = primary,
        preferred = preferred,
        fields = fields,
    )
}

fn decorator(citizen: &Citizen) -> String {
    format!(
        concat!(
            "\nexport function make{type}Decorator(collection: {type}[]): DecoratorFunction {{\n",
            "  return (story, {{ args }}) => {{\n    const {c} = get{type}FromArgs(args as {type}Args, collection);\n\n",
            "    // eslint-disable-next-line @typescript-eslint/no-unsafe-return\n",
            "    return story({{ args: {{ ...args, {c} }} }});\n  }};\n}}\n"
        ),
        type = citizen.type_name,
        c = citizen.constituent,
    )
}

/// The meta factory, rendered in the hand-written house shape: `argTypes`
/// and `decorators` as named constants, the `decorators` normalization
/// for the CSF union (`DecoratorFunction | DecoratorFunction[] | undefined`)
/// — spreading `meta.decorators ?? []` breaks when it is a single function —
/// and argTypes delegated to the preset wrapper rather than re-stating it.
fn meta(citizen: &Citizen) -> String {
    format!(
        concat!(
            "\nexport function make{type}Meta(\n  collection: {type}[],\n  {c}: {type},\n",
            "  options?: {{ category?: string; subcategory?: string }}\n): (meta: Meta) => Meta {{\n",
            "  return (meta: Meta): Meta => {{\n",
            "    const argTypes = {{\n      ...make{type}ArgTypesWithPreset(collection, options),\n",
            "      ...meta.argTypes\n    }};\n",
            "    const decorators = meta.decorators\n",
            "      ? Array.isArray(meta.decorators)\n",
            "        ? meta.decorators\n        : [meta.decorators]\n      : [];\n\n",
            "    return {{\n      ...meta,\n      argTypes,\n",
            "      args: {{ ...meta.args, ...get{type}DefaultArgs({c}) }},\n",
            "      decorators: [...decorators, make{type}Decorator(collection)]\n    }};\n  }};\n}}\n"
        ),
        type = citizen.type_name,
        c = citizen.constituent,
    )
}

fn create(citizen: &Citizen, body: &str, _preferred: &str, preferred_pascal: &str) -> String {
    let plural = Name::parse(&citizen.constituent).plural_kebab();
    let mut text = String::from("import { Type } from '@warp-drive/core/types/symbols';\n\n");
    let mut targets: Vec<(String, String, String)> = Vec::new();
    for property in citizen
        .properties
        .iter()
        .filter(|p| p.kind == sparch_model::PropertyKind::Reference)
    {
        if let Some(relation) = &property.relation {
            let entry = (
                relation.target_composite.clone(),
                relation.target.clone(),
                relation.target_type.clone(),
            );
            if !targets.contains(&entry) {
                targets.push(entry);
            }
        }
    }
    targets.sort();
    for (composite, target, pascal) in &targets {
        let list = Name::parse(target).render_plural(Case::Screaming);
        text.push_str(&format!(
            "import {{ {list}, find{pascal}BySlug }} from '{}';\n",
            Layout::test_support_alias(composite)
        ));
    }
    if let Some(primary) = citizen.fixtures.first() {
        text.push_str("import { CUSTOM } from '#tests/support/storybook.ts';\n");
        text.push_str(&format!(
            "\nimport {{ find{}By{}, {} }} from './fixtures/{plural}';\n",
            citizen.type_name, preferred_pascal, primary.const_name
        ));
    }
    text.push_str(&format!(
        "\nimport type {{ {} }} from '{}';\n",
        citizen.type_name,
        Layout::barrel_alias(&citizen.composite)
    ));
    text.push_str("import type { Meta } from 'ember-storybook';\n");
    text.push_str("import type { Conditional, DecoratorFunction, InputType } from 'storybook/internal/csf';\n");
    text.push('\n');
    text.push_str(body);
    text
}
