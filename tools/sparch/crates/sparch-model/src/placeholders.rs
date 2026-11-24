//! The template substitution engine.
//!
//! Placeholders are enclosed in angle brackets and carry the case they need
//! (`<-kebab>`, `<_snake>`, `<Pascal>`, `<camel>`), or they are prose slots
//! (`<describe the situation>`) filled verbatim. A variable placeholder
//! immediately followed by `s` at a word boundary pluralizes its value.
//! Rendering is total: a placeholder neither variable nor slot fails the
//! run, it never renders silently.

use std::collections::BTreeMap;

use crate::naming::{Case, Name, pluralize};

const PLACEHOLDER_VARS: &[&str] = &[
    "command",
    "event",
    "subdomain",
    "operation",
    "entity",
    "value_object",
    "composite",
    "constituent",
    "domain_object",
    "query",
    "public_api",
    "action",
    "jsonapi_type",
    "field",
    "validator",
    "object",
];

pub type Vars = BTreeMap<String, String>;
pub type Slots = BTreeMap<String, String>;

/// The known variable names, in canonical snake_case.
pub fn variables() -> &'static [&'static str] {
    PLACEHOLDER_VARS
}

enum Classified {
    Variable { key: String, casing: Case },
    Slot { text: String },
}

fn classify(raw: &str) -> Classified {
    let (casing, core) = casing_of(raw);
    let Some(casing) = casing else {
        return Classified::Slot {
            text: raw.to_string(),
        };
    };
    let name = Name::parse(core);
    let joined = name.words().join("_");
    if !name.words().is_empty() && PLACEHOLDER_VARS.contains(&joined.as_str()) {
        Classified::Variable {
            key: joined,
            casing,
        }
    } else {
        Classified::Slot {
            text: raw.to_string(),
        }
    }
}

/// Detects the casing from the notation. The `Prose` marker
/// (`None` here) means the body carries spaces and is filled as a slot.
fn casing_of(body: &str) -> (Option<Case>, &str) {
    if let Some(rest) = body.strip_prefix('-') {
        (Some(Case::Kebab), rest)
    } else if let Some(rest) = body.strip_prefix('_') {
        (Some(Case::Snake), rest)
    } else if body.contains(' ') {
        (None, body)
    } else if body.contains('-') {
        (Some(Case::Kebab), body)
    } else if body.contains('_') {
        (Some(Case::Snake), body)
    } else if body.chars().next().is_some_and(|c| c.is_uppercase()) {
        (Some(Case::Pascal), body)
    } else {
        // camel is the default notation — a body with any uppercase in the
        // middle is camel, a plain body renders as camel unchanged
        (Some(Case::Camel), body)
    }
}

/// One placeholder found by the scan: the raw inner text plus whether a
/// plural `s` follows it at a word boundary.
fn scan(template: &str) -> Vec<(usize, usize, String, bool)> {
    let bytes = template.as_bytes();
    let mut found = Vec::new();
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] != b'<' {
            i += 1;
            continue;
        }
        // inner text: up to the first `>`, no nesting
        let Some(close_rel) = bytes[i + 1..].iter().position(|b| *b == b'>') else {
            // an unclosed `<` cannot match; keep looking rather than stopping
            i += 1;
            continue;
        };
        let inner_start = i + 1;
        let inner_end = i + 1 + close_rel;
        let inner = &template[inner_start..inner_end];
        let after = inner_end + 1;
        // `s` immediately after, not followed by an alphanumeric or `_`
        let plural = bytes.get(after) == Some(&b's')
            && !bytes
                .get(after + 1)
                .is_some_and(|b| b.is_ascii_alphanumeric() || *b == b'_');
        found.push((i, after + usize::from(plural), inner.to_string(), plural));
        i = after;
    }
    found
}

/// Placeholder bodies (raw inner text) in template order.
pub fn bodies(template: &str) -> Vec<String> {
    scan(template)
        .into_iter()
        .map(|(_, _, inner, _)| inner)
        .collect()
}

/// Bodies that neither `vars` nor `slots` resolve.
pub fn unresolved(template: &str, vars: &Vars, slots: &Slots) -> Vec<String> {
    bodies(template)
        .into_iter()
        .filter(|raw| match classify(raw) {
            Classified::Variable { key, .. } => !vars.contains_key(&key),
            Classified::Slot { text } => !slots.contains_key(&text),
        })
        .collect()
}

/// Renders `template`, substituting every placeholder.
pub fn render(template: &str, vars: &Vars, slots: &Slots) -> Result<String, Vec<String>> {
    let unknown = unresolved(template, vars, slots);
    if !unknown.is_empty() {
        return Err(unknown);
    }
    let found = scan(template);
    let mut out = String::new();
    let mut cursor = 0usize;
    for (start, end, raw, plural) in found {
        out.push_str(&template[cursor..start]);
        let value = match classify(&raw) {
            Classified::Variable { key, casing } => {
                let value = &vars[&key];
                render_value(value, casing, plural)
            }
            Classified::Slot { text } => {
                format!("{}{}", slots[&text], if plural { "s" } else { "" })
            }
        };
        out.push_str(&value);
        cursor = end;
    }
    out.push_str(&template[cursor..]);
    Ok(out)
}

fn render_value(value: &str, casing: Case, plural: bool) -> String {
    let name = Name::parse(value);
    let name = if name.words().is_empty() {
        Name::from_words(&[value])
    } else {
        name
    };
    if plural {
        pluralize(&name.render(casing))
    } else {
        name.render(casing)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn vars() -> Vars {
        Vars::from_iter(
            [
                ("domain_object", "catalog-apparatus"),
                ("subdomain", "catalog"),
                ("composite", "equipment"),
                ("constituent", "widget"),
                ("operation", "catalog-apparatus"),
                ("validator", "unique-slug"),
            ]
            .map(|(k, v)| (k.to_string(), v.to_string())),
        )
    }

    fn slots() -> Slots {
        Slots::from_iter([(
            "describe the situation".to_string(),
            "everything".to_string(),
        )])
    }

    #[test]
    fn casings_render() {
        let v = vars();
        let s = slots();
        assert_eq!(
            render("<_domain_object>", &v, &s).unwrap(),
            "catalog_apparatus"
        );
        assert_eq!(
            render("<-domain-object>", &v, &s).unwrap(),
            "catalog-apparatus"
        );
        assert_eq!(
            render("<DomainObject>", &v, &s).unwrap(),
            "CatalogApparatus"
        );
        assert_eq!(
            render("<domainObject>", &v, &s).unwrap(),
            "catalogApparatus"
        );
        assert_eq!(render("<composite>", &v, &s).unwrap(), "equipment");
    }

    #[test]
    fn plural_s_at_word_boundary() {
        let v = vars();
        let s = slots();
        assert_eq!(
            render("<-domain-object>s", &v, &s).unwrap(),
            "catalog-apparatuses"
        );
        assert_eq!(
            render("<DomainObject>s", &v, &s).unwrap(),
            "CatalogApparatuses"
        );
        // an `s` that is part of following text stays alone
        assert_eq!(
            render("<DomainObject>Aggregate", &v, &s).unwrap(),
            "CatalogApparatusAggregate"
        );
    }

    #[test]
    fn prose_slots_are_verbatim() {
        let v = vars();
        let s = slots();
        assert_eq!(
            render("Describe it: <describe the situation>", &v, &s).unwrap(),
            "Describe it: everything"
        );
    }

    #[test]
    fn unknown_names_fall_to_slots() {
        // `not_a_variable` is not in the variable list — a slot key, verbatim
        let v = vars();
        let s = Slots::from_iter([("not_a_variable".to_string(), "filled".to_string())]);
        assert_eq!(render("<not_a_variable>", &v, &s).unwrap(), "filled");
    }

    #[test]
    fn rendering_is_total() {
        let v = vars();
        let s = slots();
        let err = render("<nobody_knows>", &v, &s).unwrap_err();
        assert_eq!(err, vec!["nobody_knows".to_string()]);
    }

    #[test]
    fn path_templates_round_trip() {
        let v = vars();
        let s = slots();
        assert_eq!(
            render(
                "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/read_model.ex",
                &v,
                &s
            )
            .unwrap(),
            "services/api/lib/sportipedia/catalog/equipment/catalog_apparatus/read_model.ex"
        );
    }
}
