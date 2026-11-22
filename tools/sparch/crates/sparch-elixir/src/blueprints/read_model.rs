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

/// The join table name for a `many_to_many` edge that declares none: the
/// two plural table names of the pair, sorted and joined by `_` — the
/// Ecto association guide's `movies_actors` shape, fixed by rule so both
/// sides of the edge derive the same table.
pub fn derive_join_table(a: &str, b: &str) -> String {
    let mut names = [
        sparch_model::Name::parse(a).render_plural(sparch_model::Case::Snake),
        sparch_model::Name::parse(b).render_plural(sparch_model::Case::Snake),
    ];
    names.sort();
    names.join("_")
}

/// The association target: the far read model's full module and its last
/// segment, plus the context that rendered it (for its own fields).
pub struct Target {
    pub module: String,
    pub short: String,
    pub ctx: Context,
}

pub fn target_of(ctx: &Context, read_model_name: &str) -> Option<Target> {
    let tctx = ctx.target_context(read_model_name)?;
    let module = tctx.render_or_panic(MODULE);
    let short = module.rsplit('.').next().unwrap_or(&module).to_string();
    Some(Target {
        module,
        short,
        ctx: tctx,
    })
}

/// The child edge a parent-side association binds to through `inverse`:
/// the far read model's `belongs_to` property of that name, with the
/// database field Ecto must point `foreign_key:` at.
fn child_edge(ctx: &Context, relation: &sparch_model::Relation) -> Option<(Befield, String)> {
    let inverse = relation.inverse.as_deref()?;
    let tctx = ctx.target_context(&relation.to)?;
    let edge = tctx
        .fields
        .iter()
        .find(|f| f.name == inverse && f.relation.as_ref().is_some_and(|r| r.kind == sparch_model::RelationKind::BelongsTo))?;
    Some((edge.clone(), edge.column()))
}

/// One `typed_schema` line per property. A plain property stays a field; a
/// relation renders its Ecto association macro — `belongs_to` carrying the
/// column (only spelled out when it differs from the derivation), the
/// parent kinds carrying the binding `foreign_key:` / `join_through:`.
/// Returns `(macro name, key, line)` — the alias units are assembled by
/// the caller from the modules the lines mention.
fn schema_entry(ctx: &Context, f: &Befield) -> Option<(String, String, String)> {
    let Some(relation) = &f.relation else {
        let ecto = Context::ecto_type(f);
        return Some((
            "field".to_string(),
            format!(":{}", f.name),
            format!("field :{}, {ecto}", f.name),
        ));
    };
    let target = target_of(ctx, &relation.to)?;
    match relation.kind {
        sparch_model::RelationKind::BelongsTo => {
            let column = f.column();
            let line = if column == format!("{}_id", f.name) {
                format!("belongs_to :{}, {}", f.name, target.short)
            } else {
                format!(
                    "belongs_to :{}, {}, foreign_key: :{}",
                    f.name, target.short, column
                )
            };
            Some(("belongs_to".to_string(), format!(":{}", f.name), line))
        }
        sparch_model::RelationKind::HasOne | sparch_model::RelationKind::HasMany => {
            let macro_ = if relation.kind == sparch_model::RelationKind::HasOne {
                "has_one"
            } else {
                "has_many"
            };
            let foreign_key = match child_edge(ctx, relation) {
                Some((_, column)) if column != format!("{}_id", ctx.constituent) => {
                    format!(", foreign_key: :{column}")
                }
                _ => String::new(),
            };
            let line = format!(
                "{macro_} :{}, {}{foreign_key}",
                f.name, target.short
            );
            Some((macro_.to_string(), format!(":{}", f.name), line))
        }
        sparch_model::RelationKind::ManyToMany => match &relation.join_model {
            Some(model_name) => {
                let join = target_of(ctx, model_name)?;
                let keys = join_keys(ctx, &join.ctx, &target)?;
                let line = format!(
                    "many_to_many :{}, {}, join_through: {}, join_keys: [{keys}]",
                    f.name, target.short, join.short
                );
                Some((
                    "many_to_many".to_string(),
                    format!(":{}", f.name),
                    line,
                ))
            }
            None => {
                let table = relation.join_table.clone().unwrap_or_else(|| {
                    derive_join_table(&ctx.constituent, &relation.to)
                });
                let line = format!(
                    "many_to_many :{}, {}, join_through: \"{table}\"",
                    f.name, target.short
                );
                Some(("many_to_many".to_string(), format!(":{}", f.name), line))
            }
        },
    }
}

/// The `join_keys` for a `join_model` link: the join model's own two
/// `belongs_to` columns, owner side first, each pointing at the far
/// schema's primary key — read from the join model, never guessed.
fn join_keys(ctx: &Context, join: &Context, far: &Target) -> Option<String> {
    let column_to = |name: &str| {
        join.fields
            .iter()
            .find(|f| {
                f.relation
                    .as_ref()
                    .is_some_and(|r| r.kind == sparch_model::RelationKind::BelongsTo && r.to == name)
            })
            .map(|f| f.column())
    };
    let owner = column_to(&ctx.constituent)?;
    let other = column_to(&far.ctx.constituent)?;
    Some(format!("{owner}: :id, {other}: :id"))
}

/// Every module a relation line names — aliased so the schema reads
/// associations by their short names, one alias unit per module.
fn relation_aliases(ctx: &Context) -> Vec<String> {
    let mut modules: Vec<String> = Vec::new();
    for f in schema_fields(ctx) {
        let Some(relation) = &f.relation else { continue };
        for name in std::iter::once(relation.to.clone()).chain(relation.join_model.clone()) {
            if let Some(t) = target_of(ctx, &name)
                && !modules.contains(&t.module)
            {
                modules.push(t.module);
            }
        }
    }
    modules.sort();
    modules
}

fn all_field_atoms(ctx: &Context) -> String {
    let mut atoms: Vec<String> = vec![":id".to_string()];
    atoms.extend(
        schema_fields(ctx)
            .iter()
            .filter(|f| !f.is_virtual())
            .map(|f| format!(":{}", f.column())),
    );
    atoms.join(", ")
}

fn required_field_atoms(ctx: &Context) -> String {
    ctx.fields
        .iter()
        .filter(|f| f.required && !f.is_virtual())
        .map(|f| format!(":{}", f.column()))
        .collect::<Vec<_>>()
        .join(", ")
}

fn updatable_field_atoms(ctx: &Context) -> String {
    schema_fields(ctx)
        .iter()
        .filter(|f| !f.is_virtual())
        .map(|f| format!(":{}", f.column()))
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

    // aliases for every module a relation names — one unit per module,
    // sorted into the alias block
    for module in relation_aliases(ctx) {
        let render = format!("alias {module}");
        let check_module = module.clone();
        let sort_key = module.clone();
        units.push(Unit {
            id: UnitId::Alias(module),
            check: Box::new(move |f| f.has_alias(&check_module)),
            render: Box::new(move || render.clone()),
            place: Placement::Head {
                rank: Rank::Alias,
                alias_sort_key: Some(sort_key),
            },
            requires: Vec::new(),
            stale: None,
        });
    }

    // schema fields inside typed_schema — plain fields and the relation
    // associations, in canonical field order; the parent-side kinds get
    // their association macro and no column
    for f in schema_fields(ctx) {
        let Some((macro_name, key, render)) = schema_entry(ctx, &f) else {
            continue;
        };
        let wrapper = format!(
            "typed_schema \"{}\" do\n{{unit}}\n\n  timestamps()\nend",
            ctx.constituent
        );
        let check_macro = macro_name.clone();
        let check_key = key.clone();
        units.push(Unit {
            id: UnitId::Field(f.name.clone()),
            check: Box::new(move |file| file.has_entry(&check_macro, &check_key)),
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use sparch_model::Model;
    use std::path::{Path, PathBuf};

    fn corpus() -> PathBuf {
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../fixtures/domain-model")
            .canonicalize()
            .expect("shared fixture corpus")
    }

    fn ctx_for(name: &str) -> Context {
        let model = Model::load(&corpus());
        let element = model
            .resolve(&format!("read-model.{name}"), &[])
            .expect("read model");
        Context::build(
            &model,
            &element,
            &ContextOptions {
                repo_root: PathBuf::from("/repo"),
                ..Default::default()
            },
        )
        .expect("context")
    }

    fn entry_lines(ctx: &Context) -> Vec<String> {
        schema_fields(ctx)
            .iter()
            .filter_map(|f| schema_entry(ctx, f).map(|(_, _, line)| line))
            .collect()
    }

    #[test]
    fn belongs_to_renders_the_association_and_the_column_atoms() {
        let ctx = ctx_for("position");
        let lines = entry_lines(&ctx);
        assert!(
            lines
                .iter()
                .any(|l| l == "belongs_to :apparatus, ApparatusReadModel")
        );
        assert!(lines.iter().any(|l| {
            l == "belongs_to :instrument, InstrumentReadModel, foreign_key: :installed_instrument_id"
        }));
        // cast and required lists speak the column, not the edge name
        assert_eq!(
            all_field_atoms(&ctx),
            ":id, :title, :raw_slug, :slug, :apparatus_id, :description, :installed_instrument_id"
        );
        // the far modules arrive as aliases
        let aliases = relation_aliases(&ctx);
        assert!(aliases.contains(&"Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel".to_string()));
        assert!(aliases.contains(&"Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel".to_string()));
    }

    #[test]
    fn parent_sides_render_associations_not_columns() {
        let ctx = ctx_for("apparatus");
        let lines = entry_lines(&ctx);
        // has_many and has_one point at the child's edge bound by inverse;
        // the derived child column matches the default, so no foreign_key
        assert!(
            lines
                .iter()
                .any(|l| l == "has_many :positions, PositionReadModel")
        );
        assert!(
            lines
                .iter()
                .any(|l| l == "has_one :certification, ApparatusCertificationReadModel")
        );
        // the plain join table is the sorted plural pair
        assert!(lines.iter().any(|l| {
            l == "many_to_many :tags, TagReadModel, join_through: \"apparatuses_tags\""
        }));
        // nothing virtual reaches the cast lists
        let atoms = updatable_field_atoms(&ctx);
        for absent in [":positions", ":certification", ":tags"] {
            assert!(!atoms.contains(absent), "{absent} must not be cast: {atoms}");
        }
    }

    #[test]
    fn two_edges_to_one_target_keep_their_own_names_and_columns() {
        let ctx = ctx_for("exercise");
        let lines = entry_lines(&ctx);
        assert!(
            lines
                .iter()
                .any(|l| l == "belongs_to :primary_apparatus, ApparatusReadModel")
        );
        // the override spells foreign_key and never reaches a cast as
        // `safety_apparatus` — the column is what the changeset consumes
        assert!(lines.iter().any(|l| {
            l == "belongs_to :safety_apparatus, ApparatusReadModel, foreign_key: :backup_apparatus_id"
        }));
        let atoms = updatable_field_atoms(&ctx);
        assert!(atoms.contains(":primary_apparatus_id"), "{atoms}");
        assert!(atoms.contains(":backup_apparatus_id"), "{atoms}");
    }

    #[test]
    fn join_model_links_through_its_schema_and_declared_keys() {
        let ctx = ctx_for("exercise");
        let lines = entry_lines(&ctx);
        assert!(lines.iter().any(|l| {
            l == "many_to_many :tags, TagReadModel, join_through: ExerciseTagReadModel, join_keys: [exercise_id: :id, tag_id: :id]"
        }));
        let aliases = relation_aliases(&ctx);
        assert!(aliases.contains(&"Sportipedia.Catalog.Exercises.ExerciseTag.ExerciseTagReadModel".to_string()));
    }

    #[test]
    fn a_has_one_child_inverts_the_required_atom_to_its_column() {
        let ctx = ctx_for("apparatus-certification");
        let lines = entry_lines(&ctx);
        assert!(
            lines
                .iter()
                .any(|l| l == "belongs_to :apparatus, ApparatusReadModel")
        );
        let required = required_field_atoms(&ctx);
        assert_eq!(required, ":id, :apparatus_id, :level");
    }

    #[test]
    fn derived_join_table_sorts_the_plural_pair() {
        assert_eq!(derive_join_table("movement", "tag"), "movements_tags");
        assert_eq!(derive_join_table("apparatus", "tag"), "apparatuses_tags");
        assert_eq!(derive_join_table("tag", "apparatus"), "apparatuses_tags");
    }
}
