//! `schema` — the WarpDrive resource schema plus the citizen's
//! registration: the subdomain barrel (`index.ts`) and the app host
//! (`config.ts`).

use sparch_model::{Case, Citizen, Name, PropertyKind};

use super::{Output, declaration, import, jsdoc, member, out};
use crate::{
    layout::Layout,
    plan::{FilePlan, Place, Presence, Unit},
};

pub fn plan(citizen: &Citizen, layout: &Layout) -> Output {
    let schema_const = schema_const(citizen);
    let configure_fn = configure_fn(citizen);
    let schema_text = schema(citizen, &schema_const);

    let barrel_units = vec![
        import(
            &format!("./schemas/{}.ts", citizen.constituent),
            false,
            &schema_const,
        ),
        member("schema.registerResources([", &schema_const),
        declaration(
            &configure_fn,
            configure_fn_text(&configure_fn, &schema_const),
        ),
        import("@warp-drive/core/reactive", true, "SchemaService"),
        export_type_unit(citizen),
    ];

    let config_units = vec![
        import(
            &Layout::barrel_alias(&citizen.composite),
            false,
            &configure_fn,
        ),
        Unit {
            id: format!("{configure_fn} call"),
            text: format!("\n  {configure_fn}(store.schema);"),
            presence: Presence::Line(format!("{configure_fn}(store.schema);")),
            place: Place::AfterLastLine {
                // sibling citizens first, then the house anchor: every app
                // registers schemas against the store it looks up
                needles: vec![
                    "Schema(store.schema);".to_string(),
                    "service:store') as Store;".to_string(),
                ],
            },
            member: None,
            gate: vec![],
            companions: vec![],
        },
    ];

    out(vec![
        FilePlan {
            path: layout.schema(),
            host: false,
            create: Some(format!(
                "import {{ withDefaults }} from '@warp-drive/legacy/model/migration-support';\n\n{schema_text}"
            )),
            units: vec![declaration(&schema_const, schema_text)],
        },
        FilePlan {
            path: layout.barrel(),
            host: false,
            create: Some(barrel_create(citizen, &configure_fn, &schema_const)),
            units: barrel_units,
        },
        FilePlan {
            path: layout.config(),
            host: true,
            create: None,
            units: config_units,
        },
    ])
}

pub fn schema_const(citizen: &Citizen) -> String {
    format!("{}Schema", citizen.constituent)
}

pub fn configure_fn(citizen: &Citizen) -> String {
    format!(
        "configure{}Schema",
        Name::parse(&citizen.composite).render(Case::Pascal)
    )
}

/// The interface export line of the barrel — a text unit, not a
/// declaration: the AST sees only the specifier.
fn export_type_unit(citizen: &Citizen) -> Unit {
    let path = format!("'./domain-objects/{0}/{0}.ts'", citizen.constituent);
    let line = format!("export type {{ {} }} from {path};", citizen.type_name);
    Unit {
        id: format!("export type {}", citizen.type_name),
        text: format!("{}\n{line}\n", jsdoc(&["@category Public API"]).trim_end()),
        presence: Presence::Line(line),
        place: Place::Eof,
        member: None,
        gate: Vec::new(),
        companions: vec![],
    }
}

fn schema(citizen: &Citizen, schema_const: &str) -> String {
    // pure declaration — the import lives only in the creation header, so
    // a `--force` rewrite replaces the const and nothing else
    let mut text = format!(
        "export const {schema_const} = withDefaults({{\n  type: '{}',\n  fields: [\n",
        citizen.constituent
    );
    for property in citizen
        .properties
        .iter()
        .filter(|p| p.kind == PropertyKind::Attribute)
    {
        text.push_str(&format!(
            "    {{ kind: 'attribute', name: '{}' }},\n",
            property.ts_name
        ));
    }
    for property in citizen
        .properties
        .iter()
        .filter(|p| p.kind == PropertyKind::Reference)
    {
        let Some(relation) = &property.relation else {
            continue;
        };
        let kind = match relation.cardinality {
            sparch_model::Cardinality::One => "belongsTo",
            sparch_model::Cardinality::Many => "hasMany",
        };
        let inverse = match &relation.inverse {
            Some(name) => format!("'{name}'"),
            None => "null".to_string(),
        };
        text.push_str(&format!(
            "    {{\n      kind: '{kind}',\n      name: '{}',\n      type: '{}',\n",
            property.ts_name, relation.target
        ));
        if relation.inverse.is_none() {
            text.push_str(
                "      // eslint-disable-next-line unicorn/no-null -- WarpDrive requires an explicit null inverse to mark the relationship unidirectional\n",
            );
        }
        text.push_str(&format!(
            "      options: {{ async: false, inverse: {inverse} }}\n    }},\n"
        ));
    }
    text.push_str("  ],\n  traits: ['timestamps']\n});\n");
    text
}

fn configure_fn_text(configure_fn: &str, schema_const: &str) -> String {
    format!(
        "\n/**\n * @internal\n */\nexport function {configure_fn}(schema: SchemaService) {{\n  schema.registerResources([{schema_const}]);\n}}\n"
    )
}

/// The barrel, created to match the equipment reference: module jsdoc,
/// the schema/service imports, the citizen type exports, then the
/// `// Modules` / `// Routes` / `// Data` sections — the schema
/// registration lives under `// Data`; registry and routes (Modules /
/// Routes) are the operator's to fill.
fn barrel_create(citizen: &Citizen, configure_fn: &str, schema_const: &str) -> String {
    let mut text = jsdoc(&[
        "@module Public API",
        &format!("@mergeModuleWith {}", citizen.composite),
    ]);
    text.push_str(&format!(
        "import {{ {schema_const} }} from './schemas/{}.ts';\n\n",
        citizen.constituent
    ));
    text.push_str("import type { SchemaService } from '@warp-drive/core/reactive';\n\n");
    text.push_str(&export_type_unit(citizen).text);
    text.push_str("\n// Modules\n\n// Routes\n\n// Data\n");
    text.push_str(&configure_fn_text(configure_fn, schema_const));
    text
}
