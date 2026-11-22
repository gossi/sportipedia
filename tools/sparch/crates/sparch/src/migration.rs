//! `sparch migration <read-model>` — the reference migration.
//!
//! Migrations are hand-written; this answers the create question: the
//! whole table exactly as the read model states it today, so the operator
//! can work out the delta from real truth instead of from memory. It
//! renders columns (relations through their database fields, parent-side
//! collections absent — they own none), indexes derived from the far side
//! of each edge, declared uniqueness, and, for the alphabetically first
//! side of a plain `many_to_many`, the join table. It writes nothing.

use sparch_elixir::context::{Context, ContextOptions};
use sparch_elixir::engine::find_root;
use sparch_model::{Case, Element, ElementKind, Model, Name, RelationKind};

use std::path::PathBuf;

pub struct Options {
    pub element: String,
    pub repo_root: Option<PathBuf>,
    pub model: Option<String>,
    pub cwd: PathBuf,
}

/// Load the model the same way `sparch validate` does and answer the
/// migration question for one read model.
pub fn run(opts: &Options) -> Result<String, String> {
    let repo_root = opts
        .repo_root
        .clone()
        .unwrap_or_else(|| find_root(&opts.cwd));
    let model_rel = opts.model.as_deref().unwrap_or("docs/domain-model");
    let model = Model::load(&repo_root.join(model_rel));
    let element = model
        .resolve(&opts.element, &[ElementKind::ReadModel])
        .map_err(|e| e.to_string())?;
    render(&model, &element)
}

/// The reference migration for one read model, as Ecto migration DSL,
/// ready to copy into a fresh migration file.
pub fn render(model: &Model, element: &Element) -> Result<String, String> {
    if element.kind != ElementKind::ReadModel {
        return Err(format!(
            "{} is not a read model — migrations project read models",
            element.address
        ));
    }
    let ctx = Context::build(
        model,
        element,
        &ContextOptions {
            repo_root: model.root.clone(),
            ..Default::default()
        },
    )
    .map_err(|e| format!("cannot build context: {e:?}"))?;

    let table = ctx.constituent.clone();
    let prefix = ctx.subdomain.clone();
    let mut out = String::new();
    out.push_str(&format!(
        "# reference migration for read-model {table} — copy into a new migration\n\ncreate table({}, primary_key: false, prefix: \"{prefix}\") do\n  add :id, :binary_id, primary_key: true\n",
        table_atom(&table)
    ));

    // storage columns in canonical field order; parent-side kinds own
    // none and are skipped whole. Edge columns are recorded for the
    // index pass.
    let mut edge_columns: Vec<(String, String, String)> = Vec::new();
    for f in ctx.fields.iter().filter(|f| f.name != "id") {
        match &f.relation {
            Some(relation) if relation.kind.is_virtual() => continue,
            Some(relation) => {
                let column = f.column();
                let null = if f.required { ", null: false" } else { "" };
                out.push_str(&format!("  add :{column}, :binary_id{null}\n"));
                edge_columns.push((column, relation.to.clone(), f.name.clone()));
            }
            None => {
                let ty = Context::ecto_type(f);
                let null = if f.required { ", null: false" } else { "" };
                out.push_str(&format!("  add :{}, {ty}{null}\n", f.name));
            }
        }
    }
    out.push_str("  timestamps(type: :utc_datetime_usec)\nend\n");

    // one index per edge column, upgraded to unique where the far side
    // binds it as a has_one — both sides of the edge decide its shape
    let uniques = unique_fields(&ctx);
    for (column, to, property) in &edge_columns {
        let statement = if is_has_one_binding(model, &table, to, property) {
            "create unique_index"
        } else {
            "create index"
        };
        out.push_str(&format!(
            "\n{statement}({}, [:{column}], prefix: \"{prefix}\")",
            table_atom(&table)
        ));
    }
    for field in &uniques {
        out.push_str(&format!(
            "\ncreate unique_index({}, [:{field}], prefix: \"{prefix}\")",
            table_atom(&table)
        ));
    }

    // the join table of a plain many_to_many, rendered once per pair:
    // this model is its alphabetically first side
    for f in ctx.fields.iter().filter(|f| f.name != "id") {
        let Some(relation) = &f.relation else { continue };
        if relation.kind != RelationKind::ManyToMany || relation.join_model.is_some() {
            continue;
        }
        let mut pair = [table.clone(), relation.to.clone()];
        pair.sort();
        if pair[0] != table {
            continue;
        }
        let joined = if let Some(jt) = &relation.join_table {
            jt.clone()
        } else {
            sparch_elixir::blueprints::read_model::derive_join_table(&table, &relation.to)
        };
        let (a, b) = (pair[0].clone(), pair[1].clone());
        // join columns follow the schema names, snake-cased — the same
        // inflection Ecto's default join_keys use
        let (a_col, b_col) = (
            format!("{}_id", Name::parse(&a).render(Case::Snake)),
            format!("{}_id", Name::parse(&b).render(Case::Snake)),
        );
        out.push_str(&format!(
            "\n# link table of the many_to_many between {a} and {b}\ncreate table({}, primary_key: false, prefix: \"{prefix}\") do\n  add :{a_col}, :binary_id, null: false\n  add :{b_col}, :binary_id, null: false\nend\n\ncreate unique_index({}, [:{a_col}, :{b_col}], prefix: \"{prefix}\")",
            table_atom(&joined),
            table_atom(&joined)
        ));
    }
    Ok(out)
}

/// Fields the model's unique rules name — the same resolution the
/// read model blueprint casts into `unique_constraint`.
fn unique_fields(ctx: &Context) -> Vec<String> {
    let mut fields = ctx.unique_fields();
    fields.sort();
    fields.dedup();
    fields
}

/// A migration identifier for a table name: bare atom when it is one,
/// quoted when the kebab name would break the syntax.
fn table_atom(name: &str) -> String {
    if name.contains('-') {
        format!(":\"{name}\"")
    } else {
        format!(":{name}")
    }
}

/// Whether the far side declares the has_one that binds this edge,
/// making the index unique rather than plain: a has_one on the target
/// whose `to` names this model and whose `inverse` names this property.
fn is_has_one_binding(model: &Model, table: &str, to: &str, property: &str) -> bool {
    let Some(far) = model.find(ElementKind::ReadModel, to) else {
        return false;
    };
    sparch_model::fields(&far).iter().any(|q| {
        q.relation.as_ref().is_some_and(|r| {
            r.kind == RelationKind::HasOne
                && r.to == table
                && r.inverse.as_deref() == Some(property)
        })
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn corpus_model() -> Model {
        let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../fixtures/domain-model")
            .canonicalize()
            .expect("fixture corpus");
        Model::load(&root)
    }

    fn render_name(name: &str) -> String {
        let model = corpus_model();
        let element = model
            .resolve(&format!("read-model.{name}"), &[])
            .expect("fixture read model");
        render(&model, &element).expect("renders")
    }

    #[test]
    fn edges_render_columns_and_their_far_side_decides_indexes() {
        let text = render_name("position");
        assert!(text.contains("create table(:position, primary_key: false, prefix: \"catalog\") do"));
        assert!(text.contains("add :apparatus_id, :binary_id\n"));
        assert!(text.contains("add :installed_instrument_id, :binary_id\n"));
        // the far side binds apparatus as has_many, not has_one: plain
        assert!(text.contains("create index(:position, [:apparatus_id], prefix: \"catalog\")"));
        assert!(text.contains("create index(:position, [:installed_instrument_id], prefix: \"catalog\")"));
        assert!(!text.contains("unique_index(:position, [:apparatus_id]"));
        // the returning collection owns no column of position
        assert!(!text.contains("positions"), "virtual kinds render nothing: {text}");
    }

    #[test]
    fn a_has_one_child_table_gets_the_unique_edge_index() {
        let text = render_name("apparatus-certification");
        assert!(
            text.contains("create table(:\"apparatus-certification\", primary_key: false"),
            "a kebab table name is quoted: {text}"
        );
        assert!(text.contains("add :apparatus_id, :binary_id, null: false"));
        assert!(
            text.contains("create unique_index(:\"apparatus-certification\", [:apparatus_id], prefix: \"catalog\")"),
            "{text}"
        );
    }

    #[test]
    fn plain_many_to_many_renders_one_join_table_per_pair() {
        let apparatus = render_name("apparatus");
        assert!(
            apparatus.contains(
                "create table(:apparatuses_tags, primary_key: false, prefix: \"catalog\") do"
            ),
            "{apparatus}"
        );
        assert!(apparatus.contains("add :apparatus_id, :binary_id, null: false"));
        assert!(apparatus.contains("add :tag_id, :binary_id, null: false"));
        assert!(
            apparatus.contains("create unique_index(:apparatuses_tags, [:apparatus_id, :tag_id]"),
            "{apparatus}"
        );
        // the far side of the same pair renders no second table
        let tag = render_name("tag");
        assert!(
            !tag.contains("apparatuses_tags"),
            "the alphabetically first side owns the rendering: {tag}"
        );
        // a modeled link renders no table here at all — it has its own
        assert!(
            !tag.contains("movements_tags") && !tag.contains("exercise_tag"),
            "join_model links are ordinary read models: {tag}"
        );
    }

    #[test]
    fn a_modeled_link_and_the_join_model_itself_render_separately() {
        let exercise = render_name("exercise");
        assert!(exercise.contains("add :primary_apparatus_id, :binary_id"));
        assert!(
            exercise.contains("add :backup_apparatus_id, :binary_id\n"),
            "optional, so no null: {exercise}"
        );
        assert!(!exercise.contains("exercise_tag"), "the link table belongs to its own read model: {exercise}");
        let link = render_name("exercise-tag");
        assert!(link.contains("create table(:\"exercise-tag\", primary_key: false"), "{link}");
        assert!(link.contains("add :exercise_id, :binary_id, null: false"));
        assert!(link.contains("add :tag_id, :binary_id, null: false"));
    }
}
