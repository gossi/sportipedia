//! Schema fields with canonical ordering, plus
//! the sparch-owned relationship keyword.
//!
//! YAML mappings lose key order, so fields canonicalize deterministically:
//! `id` first when present, then required fields in `required`-list order,
//! then optional fields alphabetically.

use serde_json::Value;

use crate::element::Element;
use crate::naming::singularize;

/// The sparch-owned relation keyword inside a schema property. Not part of
/// the ESDM core schema — an sparch convention, like `spgen.operation`:
/// `x-esdm-relation: { to: <read-model>, kind: <kind>, inverse?, column?,
/// join_table?, join_model? }`.
pub const RELATION_KEY: &str = "x-esdm-relation";

/// The four stored association kinds, named exactly as Ecto names its
/// association macros. The generator chooses the macro from this; nothing
/// is inferred from the property's type.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RelationKind {
    BelongsTo,
    HasOne,
    HasMany,
    ManyToMany,
}

impl RelationKind {
    pub fn parse(word: &str) -> Option<Self> {
        match word {
            "belongs_to" => Some(Self::BelongsTo),
            "has_one" => Some(Self::HasOne),
            "has_many" => Some(Self::HasMany),
            "many_to_many" => Some(Self::ManyToMany),
            _ => None,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Self::BelongsTo => "belongs_to",
            Self::HasOne => "has_one",
            Self::HasMany => "has_many",
            Self::ManyToMany => "many_to_many",
        }
    }

    /// The id-carrying side: the only kind with a database field, and the
    /// only kind `column` is valid on.
    pub fn carries_column(&self) -> bool {
        matches!(self, Self::BelongsTo)
    }

    /// The parent-side kinds hold no database field and are never cast.
    pub fn is_virtual(&self) -> bool {
        !self.carries_column()
    }

    /// Collections resolve to many objects on the frontend.
    pub fn is_collection(&self) -> bool {
        matches!(self, Self::HasMany | Self::ManyToMany)
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Relation {
    pub to: String,
    pub kind: RelationKind,
    /// Property name of the matching edge on the far side. Required on the
    /// parent kinds (it is the binding), optional on `belongs_to`, where
    /// absence means unidirectional.
    pub inverse: Option<String>,
    /// Database field of a `belongs_to`, derived as `<key>_id` when omitted.
    pub column: Option<String>,
    /// Explicit join table of a `many_to_many`; derived from the pair when
    /// omitted. Excludes `join_model`.
    pub join_table: Option<String>,
    /// A read model that owns the link rows; it replaces the derived join
    /// table and supplies the join keys through its own `belongs_to`
    /// properties. Excludes `join_table`.
    pub join_model: Option<String>,
}

/// The database field a `belongs_to` property occupies: the declared
/// column, or the property name plus `_id`.
pub fn column_of(key: &str, relation: &Relation) -> String {
    match &relation.column {
        Some(column) if relation.kind.carries_column() => column.clone(),
        _ => format!("{key}_id"),
    }
}

#[derive(Clone, Debug)]
pub struct Field {
    pub name: String,
    pub ty: String,
    pub format: Option<String>,
    pub description: Option<String>,
    pub required: bool,
    pub relation: Option<Relation>,
    /// Standard JSON Schema annotation: managed exclusively by the owning
    /// authority. Stays on the interface (it arrives on the wire), is never
    /// writable — no command input, no `XFields` member.
    pub read_only: bool,
    /// Standard JSON Schema annotation: never present when retrieved.
    /// Ignored by the FE entirely — not on the interface, not in fixtures.
    pub write_only: bool,
}

/// The schema block of a document: `data` for commands, `state` for
/// aggregates, `schema` for read models, `result` (or its `items`) for
/// queries.
pub fn data_schema(doc: &Value) -> Option<&Value> {
    if let Some(data) = doc.get("data").filter(|d| d.is_object()) {
        return Some(data);
    }
    if let Some(state) = doc.get("state").filter(|d| d.is_object()) {
        return Some(state);
    }
    if let Some(schema) = doc.get("schema").filter(|d| d.is_object()) {
        return Some(schema);
    }
    if let Some(result) = doc.get("result").filter(|d| d.is_object()) {
        if result.get("type").and_then(Value::as_str) == Some("array")
            && let Some(items) = result.get("items").filter(|i| i.is_object())
        {
            return Some(items);
        }
        return Some(result);
    }
    None
}

pub fn fields(element: &Element) -> Vec<Field> {
    let schema = match data_schema(&element.doc) {
        Some(schema) => schema,
        None => return vec![],
    };
    let Some(properties) = schema.get("properties").and_then(Value::as_object) else {
        return vec![];
    };
    let required: Vec<String> = schema
        .get("required")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_string)
                .collect()
        })
        .unwrap_or_default();

    let mut all: Vec<Field> = properties
        .iter()
        .map(|(name, spec)| field(name, spec, required.iter().any(|r| r == name)))
        .collect();

    // required first in required-list order, then optional alphabetically
    all.sort_by(|a, b| {
        let rank = |f: &Field| {
            if f.required {
                required
                    .iter()
                    .position(|r| r == &f.name)
                    .unwrap_or(usize::MAX)
            } else {
                usize::MAX
            }
        };
        rank(a).cmp(&rank(b)).then_with(|| a.name.cmp(&b.name))
    });

    // id first when present
    if let Some(position) = all.iter().position(|f| f.name == "id") {
        let id = all.remove(position);
        all.insert(0, id);
    }
    all
}

fn field(name: &str, spec: &Value, required: bool) -> Field {
    Field {
        name: name.to_string(),
        ty: spec
            .get("type")
            .and_then(Value::as_str)
            .unwrap_or("string")
            .to_string(),
        format: spec
            .get("format")
            .and_then(Value::as_str)
            .map(str::to_string),
        description: spec
            .get("description")
            .and_then(Value::as_str)
            .map(str::to_string),
        required,
        relation: parse_relation(spec.get(RELATION_KEY)),
        read_only: spec
            .get("readOnly")
            .and_then(Value::as_bool)
            .unwrap_or(false),
        write_only: spec
            .get("writeOnly")
            .and_then(Value::as_bool)
            .unwrap_or(false),
    }
}

fn parse_relation(value: Option<&Value>) -> Option<Relation> {
    let map = value?.as_object()?;
    let to = map.get("to").and_then(Value::as_str)?;
    let kind = RelationKind::parse(map.get("kind").and_then(Value::as_str)?)?;
    Some(Relation {
        to: to.to_string(),
        kind,
        inverse: map
            .get("inverse")
            .and_then(Value::as_str)
            .map(str::to_string),
        column: map
            .get("column")
            .and_then(Value::as_str)
            .map(str::to_string),
        join_table: map
            .get("join_table")
            .and_then(Value::as_str)
            .map(str::to_string),
        join_model: map
            .get("join_model")
            .and_then(Value::as_str)
            .map(str::to_string),
    })
}

/// Whether a property spec carries the relation keyword in a form sparch
/// cannot use: present but without a resolvable `to` and `kind`. The old
/// `cardinality` subkey has lost its meaning and is ignored, not policed;
/// a keyword that never states a kind is malformed, and validate reports
/// it while the generators treat the field as plain.
pub fn malformed_relation(spec: &Value) -> bool {
    match spec.get(RELATION_KEY) {
        None => false,
        Some(value) => parse_relation(Some(value)).is_none(),
    }
}

/// The declared database field of a relation property, for the schema it
/// belongs to: the `column` (or its `<key>_id` derivation) on the
/// id-carrying kind, and `None` on the virtual kinds, which own no field.
pub fn relation_column(field: &Field) -> Option<String> {
    let relation = field.relation.as_ref()?;
    relation.kind.carries_column().then(|| column_of(&field.name, relation))
}

/// The correlation rule between a command or event data field and a read
/// model property. A field matches by its exact name, and — where the
/// field carries an id — by the relation naming rule: `stationary_id`
/// matches the `belongs_to` property `stationary`, `tag_ids` matches the
/// `many_to_many` property `tags` after singularization. Parent-side
/// collections never write, so nothing matches `has_one`/`has_many`
/// keys with an id tail.
pub fn field_matches_property(data_field: &str, property: &Field) -> bool {
    if data_field == property.name {
        return true;
    }
    let Some(relation) = &property.relation else {
        return false;
    };
    match relation.kind {
        RelationKind::BelongsTo => data_field == format!("{}_id", property.name),
        RelationKind::ManyToMany => {
            data_field == format!("{}_ids", singularize(&property.name))
        }
        RelationKind::HasOne | RelationKind::HasMany => false,
    }
}

/// Whether a field name spells an id reference: an `_id` or `_ids` tail.
pub fn has_id_tail(data_field: &str) -> bool {
    data_field.ends_with("_id") || data_field.ends_with("_ids")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::element::ElementKind;
    use std::path::PathBuf;

    fn element(doc: serde_json::Value) -> Element {
        Element {
            kind: ElementKind::ReadModel,
            name: "thing".into(),
            scope: vec![],
            doc,
            source: PathBuf::from("thing.esdm.yaml"),
            address: "esdm:read-model=thing".into(),
        }
    }

    #[test]
    fn canonical_order_id_required_then_optional() {
        let element = element(serde_json::json!({
            "schema": {
                "type": "object",
                "properties": {
                    "zeta": { "type": "string" },
                    "description": { "type": "string" },
                    "title": { "type": "string" },
                    "id": { "type": "string", "format": "uuid" }
                },
                "required": ["title", "id"]
            }
        }));
        let names: Vec<String> = fields(&element).into_iter().map(|f| f.name).collect();
        assert_eq!(names, ["id", "title", "description", "zeta"]);
    }

    #[test]
    fn relation_keyword_parses() {
        let element = element(serde_json::json!({
            "schema": {
                "properties": { "apparatus": { "type": "string", "format": "uuid",
                    "x-esdm-relation": { "to": "apparatus", "kind": "belongs_to" } } },
                "required": ["apparatus"]
            }
        }));
        let field = &fields(&element)[0];
        let relation = field.relation.clone().expect("relation");
        assert_eq!(relation.to, "apparatus");
        assert_eq!(relation.kind, RelationKind::BelongsTo);
        assert_eq!(relation.inverse, None);
        assert_eq!(relation.column, None);
        assert_eq!(relation.join_table, None);
        assert_eq!(relation.join_model, None);
    }

    #[test]
    fn relation_keyword_parses_every_storage_subkey() {
        let element = element(serde_json::json!({
            "schema": {
                "properties": {
                    "mobile": { "type": "string", "format": "uuid",
                        "x-esdm-relation": { "to": "apparatus", "kind": "belongs_to",
                            "column": "carried_apparatus_id" } },
                    "tags": { "type": "array", "items": { "type": "string", "format": "uuid" },
                        "x-esdm-relation": { "to": "tag", "kind": "many_to_many",
                            "join_table": "movements_tags", "inverse": "movements" } }
                },
                "required": ["mobile"]
            }
        }));
        let fields = fields(&element);
        let mobile = fields.iter().find(|f| f.name == "mobile").expect("mobile");
        let relation = mobile.relation.clone().expect("mobile relation");
        assert_eq!(relation.column.as_deref(), Some("carried_apparatus_id"));
        assert_eq!(column_of("mobile", &relation), "carried_apparatus_id");
        assert_eq!(relation_column(mobile).as_deref(), Some("carried_apparatus_id"));

        let tags = fields.iter().find(|f| f.name == "tags").expect("tags");
        let relation = tags.relation.clone().expect("tags relation");
        assert_eq!(relation.kind, RelationKind::ManyToMany);
        assert_eq!(relation.join_table.as_deref(), Some("movements_tags"));
        assert_eq!(relation.inverse.as_deref(), Some("movements"));
        // virtual kinds own no database field
        assert_eq!(relation_column(tags), None);
    }

    #[test]
    fn derived_column_is_the_key_with_an_id_tail() {
        let relation = Relation {
            to: "apparatus".into(),
            kind: RelationKind::BelongsTo,
            inverse: None,
            column: None,
            join_table: None,
            join_model: None,
        };
        assert_eq!(column_of("stationary", &relation), "stationary_id");
    }

    #[test]
    fn a_keyword_without_a_kind_is_malformed_and_ignored() {
        // `cardinality` has lost its meaning; it is not policed, and the
        // field reads as plain because no kind was ever declared.
        let element = element(serde_json::json!({
            "schema": {
                "properties": { "apparatus_id": { "type": "string", "format": "uuid",
                    "x-esdm-relation": { "to": "apparatus", "cardinality": "one" } } },
                "required": ["apparatus_id"]
            }
        }));
        let field = &fields(&element)[0];
        assert_eq!(field.relation, None);
        assert!(malformed_relation(&serde_json::json!({
            "type": "string", "format": "uuid",
            "x-esdm-relation": { "to": "apparatus", "cardinality": "one" } })));
        assert!(!malformed_relation(&serde_json::json!({
            "type": "string", "format": "uuid" })));
    }
}
