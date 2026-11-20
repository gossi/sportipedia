//! The invariant patterns of the domain model, ported from
//! `SpGen.Invariant` and its three pattern modules
//! (`tools/spgen/lib/sp_gen/invariant*.ex`).
//!
//! A `namedRule` (aggregate invariant or command constraint) resolves by
//! pattern into validator descriptors, or stays unresolved when no pattern
//! claims it. The resolution reads only the rule's name and the fields the
//! citizen carries — the domain model stays the single input.

use serde_json::Value;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ValidatorKind {
    /// `unique-<field>`: the value may belong to no other domain object.
    Unique,
    /// `<constituent>-exists`: existence is checked by id.
    Exists,
    /// A rule naming citizen fields that no example blueprint covers yet —
    /// a scaffold validator the operator implements.
    Rule,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Validator {
    pub name: String,
    pub field: String,
    pub kind: ValidatorKind,
    pub rule: Option<String>,
    /// The validator's Pascal module name (`Context.pascal(name)`).
    pub module: String,
    /// The validator's file-name form.
    pub snake: String,
}

/// The Pascal module form of a kebab name — `SpGen.Context.pascal/1`:
/// split on `-`, capitalize each part's first letter, keep the rest.
pub fn pascal(name: &str) -> String {
    name.split('-')
        .map(|word| match word.chars().next() {
            Some(head) => head.to_uppercase().collect::<String>() + &word[head.len_utf8()..],
            None => String::new(),
        })
        .collect()
}

fn descriptor(rule: &Value, kind: ValidatorKind, field: &str) -> Validator {
    let name = rule.get("name").and_then(Value::as_str).unwrap_or("");
    Validator {
        name: name.to_string(),
        field: field.to_string(),
        kind,
        rule: rule.get("rule").and_then(Value::as_str).map(str::to_string),
        module: pascal(name),
        snake: name.replace('-', "_"),
    }
}

/// One rule contains `field` as a standalone word, case-insensitively —
/// the Elixir check `text =~ ~r/\b#{Regex.escape(field)}\b/i`. Word
/// boundaries are ASCII letter/digit/underscore runs.
fn names_word(text: &str, field: &str) -> bool {
    let text = text.to_lowercase();
    let field = field.to_lowercase();
    if field.is_empty() {
        return false;
    }
    let is_word = |c: char| c.is_alphanumeric() || c == '_';
    let hay: Vec<char> = text.chars().collect();
    let needle: Vec<char> = field.chars().collect();
    if needle.iter().any(|c| !is_word(*c)) {
        // `Regex.escape` of a field name with punctuation still matched as
        // regex; model field names are plain identifiers, so a non-word
        // character here means the rule cannot name it as one word.
        return text.contains(&field);
    }
    hay.windows(needle.len())
        .enumerate()
        .filter(|(_, w)| **w == needle[..])
        .any(|(i, _)| {
            let before_ok = i == 0 || !is_word(hay[i - 1]);
            let after = i + needle.len();
            let after_ok = after == hay.len() || !is_word(hay[after]);
            before_ok && after_ok
        })
}

fn unique_field(rule: &Value, field_names: &[String]) -> Option<Vec<Validator>> {
    let name = rule.get("name").and_then(Value::as_str)?;
    let field = name.strip_prefix("unique-")?;
    // The Elixir `if` yields nil when the field is not citizen-owned, so the
    // next pattern is asked — an unclaimed prefix is not an empty claim.
    field_names
        .iter()
        .any(|f| f == field)
        .then(|| vec![descriptor(rule, ValidatorKind::Unique, field)])
}

fn domain_object_exists(
    rule: &Value,
    field_names: &[String],
    constituent: &str,
) -> Option<Vec<Validator>> {
    let name = rule.get("name").and_then(Value::as_str)?;
    if name == format!("{constituent}-exists") && field_names.iter().any(|f| f == "id") {
        Some(vec![descriptor(rule, ValidatorKind::Exists, "id")])
    } else {
        None
    }
}

fn field_rule(rule: &Value, field_names: &[String]) -> Option<Vec<Validator>> {
    let name = rule.get("name").and_then(Value::as_str)?;
    let prose = rule.get("rule").and_then(Value::as_str).unwrap_or("");
    let text = format!("{name} {prose}");
    let named: Vec<&String> = field_names
        .iter()
        .filter(|field| names_word(&text, field))
        .collect();
    if named.is_empty() {
        None
    } else {
        Some(
            named
                .into_iter()
                .map(|field| descriptor(rule, ValidatorKind::Rule, field))
                .collect(),
        )
    }
}

/// Resolves one named rule against the citizen's fields: patterns in
/// registration order, first claim wins. `None` when no pattern implements
/// the rule.
pub fn resolve(rule: &Value, field_names: &[String], constituent: &str) -> Option<Vec<Validator>> {
    rule.get("name").and_then(Value::as_str)?;
    unique_field(rule, field_names)
        .or_else(|| domain_object_exists(rule, field_names, constituent))
        .or_else(|| field_rule(rule, field_names))
}

/// Splits rules into `{validators, unresolved}` in input order.
pub fn resolve_all(
    rules: &[Value],
    field_names: &[String],
    constituent: &str,
) -> (Vec<Validator>, Vec<Value>) {
    let mut validators = Vec::new();
    let mut unresolved = Vec::new();
    for rule in rules {
        match resolve(rule, field_names, constituent) {
            None => unresolved.push(rule.clone()),
            Some(descriptors) => validators.extend(descriptors),
        }
    }
    (validators, unresolved)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn fields() -> Vec<String> {
        ["id", "title", "slug"]
            .iter()
            .map(|s| s.to_string())
            .collect()
    }

    #[test]
    fn unique_pattern_claims_named_field() {
        let rule = json!({"name": "unique-slug", "rule": "the slug is unique"});
        let rules = model_rules(&rule);
        let (validators, unresolved) = resolve_all(&rules, &fields(), "widget");
        assert_eq!(unresolved.len(), 0);
        assert_eq!(validators[0].kind, ValidatorKind::Unique);
        assert_eq!(validators[0].field, "slug");
        assert_eq!(validators[0].module, "UniqueSlug");
        assert_eq!(validators[0].snake, "unique_slug");
    }

    #[test]
    fn unique_pattern_skips_unowned_field() {
        // `unique-title` where title is not citizen-owned falls to the field
        // rule pattern, which still names it — the Elixir cascade.
        let rule = json!({"name": "unique-owner", "rule": "the owner is unique"});
        let rules = model_rules(&rule);
        let (validators, unresolved) = resolve_all(&rules, &fields(), "widget");
        assert!(validators.is_empty());
        assert_eq!(unresolved.len(), 1);
    }

    #[test]
    fn exists_pattern_is_constituent_scoped() {
        let rule = json!({"name": "widget-exists", "rule": "the widget exists"});
        let rules = model_rules(&rule);
        let (validators, _un) = resolve_all(&rules, &fields(), "widget");
        assert_eq!(validators[0].kind, ValidatorKind::Exists);
        assert_eq!(validators[0].field, "id");
    }

    #[test]
    fn field_rule_claims_every_named_field() {
        let rule = json!({"name": "at-most-one", "rule": "title and slug together"});
        let rules = model_rules(&rule);
        let (validators, _un) = resolve_all(&rules, &fields(), "widget");
        assert_eq!(validators.len(), 2);
        assert!(validators.iter().all(|v| v.kind == ValidatorKind::Rule));
    }

    #[test]
    fn word_boundaries_are_exact() {
        let rule = json!({"name": "in-use-guard", "rule": "no idling allowed"});
        let rules = model_rules(&rule);
        // "id" must not match inside "idling" — the \b rule.
        let (validators, unresolved) = resolve_all(&rules, &fields(), "widget");
        assert!(validators.is_empty());
        assert_eq!(unresolved.len(), 1);
    }

    fn model_rules(rule: &Value) -> Vec<Value> {
        vec![rule.clone()]
    }
}
