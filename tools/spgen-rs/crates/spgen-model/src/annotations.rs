//! The `spgen.*` annotations, ported from `SpGen.Esdm`
//! (declared operations and effects — "declared, never guessed").

use crate::element::Element;
use serde_json::Value;

pub const OPERATION_KEY: &str = "spgen.operation";
pub const EFFECT_PREFIX: &str = "spgen.operation.";

pub const OPERATIONS: [&str; 4] = ["create", "update", "delete", "none"];
pub const QUERY_OPERATIONS: [&str; 2] = ["read", "collection"];

/// The `metadata.annotations` map of an element.
pub fn annotations(element: &Element) -> Value {
    element
        .doc
        .get("metadata")
        .and_then(|m| m.get("annotations"))
        .cloned()
        .unwrap_or(Value::Object(Default::default()))
}

/// The operation a command declares; `None` when absent or outside the
/// command vocabulary.
pub fn declared_operation(element: &Element) -> Option<String> {
    let annotations = annotations(element);
    match annotations.get(OPERATION_KEY).and_then(Value::as_str) {
        Some(v) if OPERATIONS.contains(&v) => Some(v.to_string()),
        _ => None,
    }
}

/// The operation a query declares (`read`/`collection`), `None` when absent.
pub fn declared_query_operation(element: &Element) -> Option<String> {
    let annotations = annotations(element);
    match annotations.get(OPERATION_KEY).and_then(Value::as_str) {
        Some(v) if QUERY_OPERATIONS.contains(&v) => Some(v.to_string()),
        _ => None,
    }
}

/// The declared effects of a read model as event name → effect (`create`,
/// `update`, `delete`, `none`) — `Esdm.declared_effects/1`. Invalid values
/// surface as `None` so checks can point at the exact mistake.
pub fn declared_effects(element: &Element) -> Vec<(String, Option<String>)> {
    let annotations = annotations(element);
    let mut effects: Vec<(String, Option<String>)> = annotations
        .as_object()
        .into_iter()
        .flat_map(|map| map.iter())
        .filter_map(|(key, value)| {
            let event = key.strip_prefix(EFFECT_PREFIX)?;
            if event.is_empty() {
                return None;
            }
            let effect = match value.as_str() {
                Some(v) if OPERATIONS.contains(&v) => Some(v.to_string()),
                _ => None,
            };
            Some((event.to_string(), effect))
        })
        .collect();
    effects.sort();
    effects
}
