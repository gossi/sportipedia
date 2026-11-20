//! The read model blueprint.
//!
//! Generates the shared read model (Ecto schema) and its changesets. Fixed
//! shape: `insert_changeset/2` and `update_changeset/2` always both exist.
//! Migrations are out of scope (Ecto's own generators handle them).

use crate::context::{Befield, Context};
use crate::elixir::Rank;
use crate::plan::Blueprint;
use crate::plan::{FilePlan, Placement, Unit, UnitId};

const PATH: &str =
    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/read_model.ex";
const MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel";

pub struct ReadModel;

impl ReadModel {
    /// The read model's module-name template (other blueprints alias through
    /// it).
    pub fn module_template() -> &'static str {
        MODULE
    }

    /// The read model's file path (used as a `requires` gate).
    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(PATH)
    }
}

impl Blueprint for ReadModel {
    fn name(&self) -> &'static str {
        "read_model"
    }

    fn description(&self) -> Option<&'static str> {
        Some("Generates the shared read model with its changesets")
    }

    fn source_kinds(&self) -> Vec<sparch_model::ElementKind> {
        vec![sparch_model::ElementKind::ReadModel]
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(PATH, "Ecto schema with both changesets")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        vec![FilePlan::new(
            ctx.render_or_panic(PATH),
            Some(ctx.render_or_panic(MODULE)),
            units(ctx),
        )]
    }
}

fn moduledoc_text(ctx: &Context) -> String {
    match ctx.description() {
        None => format!("Represents a {} in the {}.", ctx.constituent, ctx.composite),
        Some(desc) => desc.to_string(),
    }
}

fn schema_fields(ctx: &Context) -> Vec<Befield> {
    ctx.fields
        .iter()
        .filter(|f| f.name != "id")
        .cloned()
        .collect()
}

fn all_field_atoms(ctx: &Context) -> String {
    let mut atoms: Vec<String> = vec![":id".to_string()];
    atoms.extend(schema_fields(ctx).iter().map(|f| format!(":{}", f.name)));
    atoms.join(", ")
}

fn required_field_atoms(ctx: &Context) -> String {
    ctx.fields
        .iter()
        .filter(|f| f.required)
        .map(|f| format!(":{}", f.name))
        .collect::<Vec<_>>()
        .join(", ")
}

fn updatable_field_atoms(ctx: &Context) -> String {
    schema_fields(ctx)
        .iter()
        .map(|f| format!(":{}", f.name))
        .collect::<Vec<_>>()
        .join(", ")
}

/// fields declared unique by the aggregate's invariants / command
/// constraints get a `unique_constraint` chain step; the exact name matches
/// the default unique-index name migrations create (`<table>_<field>_index`).
fn unique_constraint_lines(ctx: &Context) -> String {
    let mut seen: Vec<String> = Vec::new();
    for field in ctx.unique_fields() {
        if !seen.contains(&field) {
            seen.push(field);
        }
    }
    seen.iter()
        .map(|field| {
            let snake = macro_underscore(field);
            format!(
                "    |> unique_constraint(:{snake}, name: :{}_{}_index)",
                ctx.constituent, snake
            )
        })
        .collect::<Vec<_>>()
        .join("\n")
}

/// `Macro.underscore/1` — camelCase to snake_case, dashes to underscores.
fn macro_underscore(name: &str) -> String {
    let mut out = String::new();
    let chars: Vec<char> = name.chars().collect();
    for (i, c) in chars.iter().enumerate() {
        if *c == '-' || *c == '_' {
            out.push('_');
            continue;
        }
        if c.is_uppercase() && i > 0 {
            let prev = chars[i - 1];
            let next_lower = chars.get(i + 1).is_some_and(|n| n.is_lowercase());
            if prev.is_lowercase() || prev.is_ascii_digit() || (prev.is_uppercase() && next_lower) {
                out.push('_');
            }
        }
        out.extend(c.to_lowercase());
    }
    out
}

fn units(ctx: &Context) -> Vec<Unit> {
    let mut units: Vec<Unit> = Vec::new();

    // @moduledoc
    {
        let text = moduledoc_text(ctx);
        units.push(Unit {
            id: UnitId::Moduledoc,
            check: Box::new(|f| f.has_moduledoc()),
            render: Box::new(move || format!("@moduledoc \"\"\"\n{text}\n\"\"\"")),
            place: Placement::Head {
                rank: Rank::Moduledoc,
                alias_sort_key: None,
            },
            requires: Vec::new(),
            stale: None,
        });
    }

    // use TypedEctoSchema
    units.push(Unit {
        id: UnitId::Use("TypedEctoSchema".into()),
        check: Box::new(|f| f.has_use("TypedEctoSchema")),
        render: Box::new(|| "use TypedEctoSchema".to_string()),
        place: Placement::Head {
            rank: Rank::Use,
            alias_sort_key: None,
        },
        requires: Vec::new(),
        stale: None,
    });

    // import Ecto.Changeset
    units.push(Unit {
        id: UnitId::Import("Ecto.Changeset".into()),
        check: Box::new(|f| f.has_import("Ecto.Changeset")),
        render: Box::new(|| "import Ecto.Changeset".to_string()),
        place: Placement::Head {
            rank: Rank::Import,
            alias_sort_key: None,
        },
        requires: Vec::new(),
        stale: None,
    });

    // attributes — the @head of read models is fixed
    {
        let attrs: [(&str, &str); 3] = [
            (
                "primary_key",
                "@primary_key {:id, :binary_id, autogenerate: false}",
            ),
            (
                "timestamps_opts",
                "@timestamps_opts [type: :utc_datetime_usec]",
            ),
            ("schema_prefix", "@schema_prefix \"TODO-subdomain\""),
        ];
        for (attr, text) in attrs {
            let render = text.replace("TODO-subdomain", &ctx.subdomain);
            let attr = attr.to_string();
            let check_attr = attr.clone();
            units.push(Unit {
                id: UnitId::Attribute(attr),
                check: Box::new(move |f| f.has_attribute(&check_attr)),
                render: Box::new(move || render.clone()),
                place: Placement::Head {
                    rank: Rank::Attribute,
                    alias_sort_key: None,
                },
                requires: Vec::new(),
                stale: None,
            });
        }
    }

    // schema fields inside typed_schema
    for f in schema_fields(ctx) {
        let key = format!(":{}", f.name);
        let ecto = Context::ecto_type(&f);
        let render = format!("field :{}, {ecto}", f.name);
        let wrapper = format!(
            "typed_schema \"{}\" do\n{{unit}}\n\n  timestamps()\nend",
            ctx.constituent
        );
        units.push(Unit {
            id: UnitId::Field(f.name.clone()),
            check: Box::new(move |file| file.has_entry("field", &key)),
            render: Box::new(move || render.clone()),
            place: Placement::Inside {
                macro_name: "typed_schema".into(),
                wrapper: Some(wrapper),
                before_trailing: Some("timestamps".into()),
            },
            requires: Vec::new(),
            stale: None,
        });
    }

    // changesets — both variants exist for every read model
    let unique = unique_constraint_lines(ctx);
    for (name, verb, atoms) in [
        ("insert_changeset", "insertion", all_field_atoms(ctx)),
        ("update_changeset", "update", updatable_field_atoms(ctx)),
    ] {
        let required_line = if name == "insert_changeset" {
            format!("    |> validate_required([{}])", required_field_atoms(ctx))
        } else {
            String::new()
        };
        // Elixir joins `validate_required` and the unique steps on one line
        // with plain spaces; the pipeline parses through them and the
        // project formatter puts every step back on its own line
        let chain = format!("{required_line}{unique}");
        let constituent = ctx.constituent.clone();
        let render = format!(
            "@doc \"\"\"\nValidates and prepares the {constituent} read model for {verb}.\n\"\"\"\ndef {name}(read_model, attrs) do\n  read_model\n  |> cast(attrs, [{atoms}])\n  {chain}\nend"
        );
        units.push(Unit {
            id: UnitId::Def(name.to_string(), 2),
            check: Box::new(move |f| f.has_def(name, 2)),
            render: Box::new(move || render.clone()),
            place: Placement::BodyEnd,
            requires: Vec::new(),
            stale: None,
        });
    }

    units
}
