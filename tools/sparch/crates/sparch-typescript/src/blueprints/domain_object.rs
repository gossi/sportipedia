//! `domain-object` — the interface and its mutable fields type.

use sparch_model::{Citizen, PropertyKind};

use super::{Output, jsdoc, union};
use crate::{
    blueprints::{declaration, out},
    layout::Layout,
    plan::FilePlan,
};

pub fn plan(citizen: &Citizen, layout: &Layout) -> Output {
    // unit texts are pure declarations — a `--force` rewrite replaces
    // exactly this range; the file header (module jsdoc + imports) lives
    // only in the creation text
    let interface = interface_declaration(citizen);
    let fields = fields_type(citizen);

    out(vec![FilePlan {
        path: layout.domain_object(),
        host: false,
        create: Some(create(citizen, &interface, &fields)),
        units: vec![
            declaration(&citizen.type_name, interface),
            declaration(&format!("{}Fields", citizen.type_name), fields),
        ],
    }])
}

/// The interface with its `@group` JSDoc — the whole declaration, nothing
/// above it.
fn interface_declaration(citizen: &Citizen) -> String {
    let mut text = jsdoc(&[
        &format!("@group {}", citizen.type_name),
        "@category Domain Object",
    ]);
    text.push_str(&format!(
        "export interface {} extends Timestamps {{\n  /** @internal */\n  readonly [Type]: '{}';\n\n",
        citizen.type_name, citizen.constituent
    ));

    for property in citizen
        .properties
        .iter()
        .filter(|p| p.kind != PropertyKind::Reference)
    {
        text.push_str(&property_line(property));
    }
    let relations: Vec<_> = citizen
        .properties
        .iter()
        .filter(|p| p.kind == PropertyKind::Reference)
        .collect();
    if !relations.is_empty() {
        text.push('\n');
        for property in relations {
            text.push_str(&property_line(property));
        }
    }

    text.push_str("}\n");
    text
}

fn header(citizen: &Citizen) -> String {
    let mut text = jsdoc(&[
        &format!("@module {}", citizen.type_name),
        "@category Domain Objects",
    ]);
    text.push('\n');
    for import in imports(citizen) {
        text.push_str(&import);
    }
    text
}

fn property_line(property: &sparch_model::citizen::Property) -> String {
    let mark = if property.optional { "?" } else { "" };
    format!(
        "  readonly {}{}: {};\n",
        property.ts_name, mark, property.ts_type
    )
}

fn imports(citizen: &Citizen) -> Vec<String> {
    let mut lines = vec![
        "import type { Type } from '@warp-drive/core/types/symbols';\n".to_string(),
        "import type { Mutable } from '@warp-drive/core/types/utils';\n".to_string(),
    ];

    let mut fields_specs = vec!["ID".to_string()];
    if citizen
        .properties
        .iter()
        .any(|p| p.kind == PropertyKind::Slug)
    {
        fields_specs.push("Slug".to_string());
    }
    lines.push(format!(
        "import type {{ {} }} from '#/support/domain-objects/fields';\n",
        fields_specs.join(", ")
    ));
    lines.push(
        "import type { Timestamps } from '#/support/domain-objects/timestamps';\n".to_string(),
    );

    // relation types, grouped by the target's barrel
    let mut by_composite: Vec<(String, Vec<String>)> = Vec::new();
    for property in citizen
        .properties
        .iter()
        .filter(|p| p.kind == PropertyKind::Reference)
    {
        if let Some(relation) = &property.relation {
            let entry = by_composite
                .iter_mut()
                .find(|(composite, _)| *composite == relation.target_composite);
            match entry {
                Some((_, types)) if !types.contains(&relation.target_type.clone()) => {
                    types.push(relation.target_type.clone())
                }
                None => by_composite.push((
                    relation.target_composite.clone(),
                    vec![relation.target_type.clone()],
                )),
                _ => {}
            }
        }
    }
    let mut by_composite: Vec<(String, Vec<String>)> = by_composite
        .into_iter()
        .map(|(composite, mut types)| {
            types.sort();
            (composite, types)
        })
        .collect();
    by_composite.sort_by(|a, b| a.0.cmp(&b.0));

    for (composite, types) in by_composite {
        lines.push(format!(
            "import type {{ {} }} from '{}';\n",
            types.join(", "),
            Layout::barrel_alias(&composite)
        ));
    }
    lines
}

pub fn fields_type(citizen: &Citizen) -> String {
    let names: Vec<String> = citizen
        .mutable_fields()
        .iter()
        .map(|p| p.ts_name.clone())
        .collect();
    format!(
        "\nexport type {}Fields = Mutable<Pick<{}, {}>>;\n",
        citizen.type_name,
        citizen.type_name,
        union(&names)
    )
}

fn create(citizen: &Citizen, interface: &str, fields: &str) -> String {
    let mut text = header(citizen);
    text.push('\n');
    text.push_str(interface);
    text.push_str(fields);
    text
}
