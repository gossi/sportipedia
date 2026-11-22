//! The fixture identity rule.
//!
//! A fixture is a read-model instance the domain model *declares*: the read
//! model's `schema.examples`. Each example names itself with a fixture key —
//! three kebab-case segments, `<composite>:<read-model>:<mnemonic>`, carried
//! in its `id` property. On the FE the key *is* the materialized id (the
//! JSON:API resource id), and a reference to another fixture resolves to the
//! named const of that fixture's file — see `sparch-typescript`'s fixtures blueprint.

use serde_json::Value;

use crate::element::Element;

/// A parsed fixture key: (composite, read-model, mnemonic).
pub type FixtureKey = (String, String, String);

/// One example, prepared for rendering into fixture code.
#[derive(Clone, Debug)]
pub struct FixtureSpec {
    pub key: String,
    pub parts: FixtureKey,
    /// The mnemonic in SCREAMING_SNAKE — the const the FE file defines
    /// (`equipment:apparatus:parallel-bars` → `PARALLEL_BARS`).
    pub const_name: String,
    /// Example properties in schema field order, only those the example
    /// carries. Values stay JSON here; rendering to TS literals is the
    /// blueprint's job, but `is_reference` marks the fixture-key values.
    pub properties: Vec<(String, Value)>,
}

fn kebab_word(text: &str) -> bool {
    let mut chars = text.chars();
    match chars.next() {
        Some(first) if first.is_ascii_lowercase() => {}
        _ => return false,
    }
    chars.all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-')
}

/// True when `value` is a well-formed fixture key (three kebab segments).
pub fn fixture_key(value: &str) -> bool {
    let segments: Vec<&str> = value.split(':').collect();
    segments.len() == 3 && segments.iter().all(|s| kebab_word(s))
}

pub fn parse_key(value: &str) -> Result<FixtureKey, String> {
    if fixture_key(value) {
        let segments: Vec<&str> = value.split(':').collect();
        Ok((
            segments[0].to_string(),
            segments[1].to_string(),
            segments[2].to_string(),
        ))
    } else {
        Err(format!(
            "\"{value}\" is not a fixture key — expected <composite>:<read-model>:<mnemonic> with kebab-case segments"
        ))
    }
}

/// The `examples` list declared on a read model element, in model order.
pub fn examples_of(element: &Element) -> Vec<Value> {
    element
        .doc
        .get("schema")
        .and_then(|s| s.get("examples"))
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
}

/// Validate a read model's examples and prepare renderable specs,
/// reporting *every* violation, never just the
/// first. `plural` is the collection const name the file will define
/// (`POSITIONS`); no mnemonic may produce it.
pub fn validate(
    element: &Element,
    composite: &str,
    plural: &str,
) -> Result<Vec<FixtureSpec>, Vec<String>> {
    let declared = crate::fields::fields(element);
    let properties: Vec<&str> = declared.iter().map(|f| f.name.as_str()).collect();
    let required: Vec<&str> = declared
        .iter()
        .filter(|f| f.required)
        .map(|f| f.name.as_str())
        .collect();

    let mut specs = Vec::new();
    let mut errors = Vec::new();

    for example in examples_of(element) {
        let Some(object) = example.as_object() else {
            continue;
        };
        let label = object
            .get("id")
            .and_then(Value::as_str)
            .map(|id| format!("\"{id}\""))
            .unwrap_or_else(|| {
                format!(
                    "\"{:?}\"",
                    object
                        .get("title")
                        .and_then(Value::as_str)
                        .unwrap_or("<unnamed>")
                )
            });

        // unknown keys
        for key in object.keys() {
            if !properties.contains(&key.as_str()) {
                errors.push(format!(
                    "example {label} carries \"{key}\", which the schema does not declare"
                ));
            }
        }
        // missing required
        for name in &required {
            if !object.contains_key(*name) {
                errors.push(format!(
                    "example {label} is missing required property \"{name}\""
                ));
            }
        }
        // the key must name its own home
        let key_parts = match object.get("id").and_then(Value::as_str) {
            None => {
                errors.push(format!(
                    "example {label} carries no id — fixtures name themselves with a fixture key"
                ));
                None
            }
            Some(id) => match parse_key(id) {
                Err(reason) => {
                    errors.push(reason);
                    None
                }
                Ok(parts) => {
                    if parts.0 != composite || parts.1 != element.name {
                        errors.push(format!(
                            "fixture key \"{id}\" names {}/{}, but this read model lives in {composite}/{} — a key must name its own home",
                            parts.0, parts.1, element.name
                        ));
                    }
                    Some((id.to_string(), parts))
                }
            },
        };
        // reference fields hold a key or a UUID
        for (name, value) in object {
            if crate::fields::has_id_tail(name)
                && let Some(text) = value.as_str()
                && !fixture_key(text)
                && !is_uuid(text)
            {
                errors.push(format!(
                    "reference value \"{text}\" is neither a fixture key nor a UUID"
                ));
            }
        }

        if let Some((key, parts)) = key_parts {
            let const_name =
                crate::naming::Name::parse(&parts.2).render(crate::naming::Case::Screaming);
            if const_name == plural {
                errors.push(format!(
                    "fixture key \"{key}\" would define {plural}, colliding with the collection const of the same file"
                ));
            }
            let ordered = declared
                .iter()
                .filter(|f| object.contains_key(&f.name))
                .map(|f| (f.name.clone(), object[&f.name].clone()))
                .collect();
            specs.push(FixtureSpec {
                key,
                parts,
                const_name,
                properties: ordered,
            });
        }
    }

    // duplicate const names
    let mut seen: Vec<String> = Vec::new();
    for spec in &specs {
        if seen.contains(&spec.const_name) {
            errors.push(format!(
                "two examples both name const {} — mnemonics must differ",
                spec.const_name
            ));
        } else {
            seen.push(spec.const_name.clone());
        }
    }

    if errors.is_empty() {
        Ok(specs)
    } else {
        Err(errors)
    }
}

fn is_uuid(text: &str) -> bool {
    let clean = text.replace('-', "");
    clean.len() == 32 && clean.chars().all(|c| c.is_ascii_hexdigit())
}

/// Every fixture key referenced from a read model's example reference fields.
pub fn referenced_keys(element: &Element) -> Vec<String> {
    let mut keys: Vec<String> = examples_of(element)
        .iter()
        .filter_map(Value::as_object)
        .flat_map(|object| {
            object.iter().filter_map(|(name, value)| {
                if crate::fields::has_id_tail(name) {
                    value
                        .as_str()
                        .filter(|v| fixture_key(v))
                        .map(str::to_string)
                } else {
                    None
                }
            })
        })
        .collect();
    keys.sort();
    keys.dedup();
    keys
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::element::ElementKind;
    use std::path::PathBuf;

    fn read_model(doc: serde_json::Value) -> Element {
        Element {
            kind: ElementKind::ReadModel,
            name: "position".into(),
            scope: vec![],
            doc,
            source: PathBuf::from("read-model.position.esdm.yaml"),
            address: "esdm:read-model=position".into(),
        }
    }

    #[test]
    fn key_grammar() {
        assert!(fixture_key("athlete:position:unicycle-riding"));
        assert!(!fixture_key("athlete:position"));
        assert!(!fixture_key("athlete:position:Unicycle"));
        assert_eq!(
            parse_key("equipment:apparatus:horizontal-bar"),
            Ok((
                "equipment".into(),
                "apparatus".into(),
                "horizontal-bar".into()
            ))
        );
    }

    #[test]
    fn validates_examples_against_the_schema() {
        let element = read_model(serde_json::json!({
            "schema": {
                "properties": {
                    "id": { "type": "string" },
                    "title": { "type": "string" },
                    "instrument_id": { "type": "string", "format": "uuid" }
                },
                "required": ["id", "title"],
                "examples": [
                    { "id": "athlete:position:riding", "title": "Riding", "instrument_id": "equipment:instrument:unicycle" },
                    { "id": "athlete:position:bad", "title": "Bad", "unknown": 1 }
                ]
            }
        }));
        let specs = validate(&element, "athlete", "POSITIONS");
        // the second example carries an unknown key — every violation lists
        assert!(matches!(&specs, Err(errors) if errors.iter().any(|e| e.contains("unknown"))));

        let element_ok = read_model(serde_json::json!({
            "schema": {
                "properties": {
                    "id": { "type": "string" },
                    "title": { "type": "string" },
                    "instrument_id": { "type": "string", "format": "uuid" }
                },
                "required": ["id", "title"],
                "examples": [
                    { "id": "athlete:position:riding", "title": "Riding", "instrument_id": "equipment:instrument:unicycle" }
                ]
            }
        }));
        let specs = validate(&element_ok, "athlete", "POSITIONS").expect("valid");
        assert_eq!(specs.len(), 1);
        assert_eq!(specs[0].const_name, "RIDING");
        assert_eq!(
            referenced_keys(&element_ok),
            vec!["equipment:instrument:unicycle"]
        );
    }
}
