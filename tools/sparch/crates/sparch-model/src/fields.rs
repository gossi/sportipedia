//! Schema fields with canonical ordering, ported from `Esdm.fields/1`, plus
//! the sparch-owned relationship keyword.
//!
//! YAML mappings lose key order, so fields canonicalize deterministically:
//! `id` first when present, then required fields in `required`-list order,
//! then optional fields alphabetically.

use serde_json::Value;

use crate::element::Element;

/// The sparch-owned relation keyword inside a schema property. Not part of
/// the ESDM core schema — an sparch convention, like `spgen.operation`:
/// `x-esdm-relation: { to: <read-model>, cardinality: one|many, inverse? }`.
pub const RELATION_KEY: &str = "x-esdm-relation";

#[derive(Clone, Debug, PartialEq)]
pub struct Relation {
    pub to: String,
    /// `one` = this instance holds one (n:1 side); `many` = it holds a
    /// collection. The relation's cardinality is the pairing of both sides.
    pub cardinality: Cardinality,
    /// Explicit inverse property name, or `None` = unidirectional.
    pub inverse: Option<String>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Cardinality {
    One,
    Many,
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
/// queries — ported from `Esdm.data_schema/1`.
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
    let cardinality = match map.get("cardinality").and_then(Value::as_str) {
        Some("many") => Cardinality::Many,
        _ => Cardinality::One,
    };
    Some(Relation {
        to: to.to_string(),
        cardinality,
        inverse: map
            .get("inverse")
            .and_then(Value::as_str)
            .map(str::to_string),
    })
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
                "properties": { "apparatusId": { "type": "string", "format": "uuid",
                    "x-esdm-relation": { "to": "apparatus", "cardinality": "one" } } },
                "required": ["apparatusId"]
            }
        }));
        let field = &fields(&element)[0];
        let relation = field.relation.clone().expect("relation");
        assert_eq!(relation.to, "apparatus");
        assert_eq!(relation.cardinality, Cardinality::One);
        assert_eq!(relation.inverse, None);
    }
}
