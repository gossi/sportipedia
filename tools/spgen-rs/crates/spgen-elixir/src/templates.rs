//! Line-level composition shared by blueprints — the port of
//! `SpGen.Templates` (`tools/spgen/lib/sp_gen/templates.ex`): `indent/2`,
//! `field_line/1`, the `validates_line` machinery with its `by:` pairs,
//! `sample_value/2` and `struct_body/1` plus the type-correct defaults and
//! the `inspect` the Elixir source relies on.

use serde_json::Value;

use spgen_model::invariants::{Validator, ValidatorKind};

use crate::context::{Befield, Context};

/// Indent every non-empty line of `text` with `n` spaces — `Templates.indent/2`.
pub fn indent(text: &str, n: usize) -> String {
    let pad = " ".repeat(n);
    text.split('\n')
        .map(|line| {
            if line.is_empty() {
                String::new()
            } else {
                format!("{pad}{line}")
            }
        })
        .collect::<Vec<_>>()
        .join("\n")
}

/// The `field` line for one data field — `Templates.field_line/1`:
/// `field :title, String.t(), enforce: true` when the model requires it.
pub fn field_line(f: &Befield) -> String {
    let base = format!("field :{}, {}", f.name, Context::elixir_type(f));
    if f.required {
        format!("{base}, enforce: true")
    } else {
        base
    }
}

/// The `validates` line for one field, merging presence with validators —
/// `Templates.validates_line/2`. Validators attached to the field add
/// `by: [function: &Module.validate/2]` with the skip option the pattern
/// demands; two validators on one field are two `by:` pairs in **one**
/// call, because `Vex.Struct.validates/2` stores validations per field and
/// a second call would replace, not extend, the first.
pub fn validates_line(f: &Befield, validators: &[Validator]) -> Option<String> {
    let mut parts: Vec<String> = Vec::new();
    if validates_presence(f) {
        parts.push("presence: true".to_string());
    }
    parts.extend(
        validators_for(f, validators)
            .into_iter()
            .map(|v| validates_by_pair(v, f)),
    );
    if parts.is_empty() {
        return None;
    }
    Some(format!("validates :{}, {}", f.name, parts.join(", ")))
}

/// Does `field` owe the line a `presence: true` part? —
/// `Templates.validates_presence?/1`.
pub fn validates_presence(f: &Befield) -> bool {
    f.required && !f.internal
}

/// The validators guarding `field`, in the order their `by:` parts appear —
/// `Templates.validators_for/2`.
pub fn validators_for<'a>(f: &Befield, validators: &'a [Validator]) -> Vec<&'a Validator> {
    validators.iter().filter(|v| v.field == f.name).collect()
}

/// The `by:` pair for one validator — `Templates.validates_by_pair/2`, the
/// exact text a `validates` line needs. The skip option belongs inside the
/// pair: Vex does not run the validator for a value the option covers.
///
/// * `:unique` → `allow_nil: true`: a partial update may omit the field.
/// * `:exists` → `allow_blank: true`: the by-id lookup must never see an
///   absent or empty id (`Repo.get/2` raises on both — a 500 the command
///   could answer).
/// * `:rule` on a field the model does not require → `allow_nil: true`:
///   the scaffold raises its `TODO:` on any value, nil included.
/// * `:rule` on a required field → none: `enforce: true` means there is no
///   nil to skip.
pub fn validates_by_pair(v: &Validator, f: &Befield) -> String {
    let base = format!("by: [function: &{}.validate/2", v.module);
    match v.kind {
        ValidatorKind::Unique => format!("{base}, allow_nil: true]"),
        ValidatorKind::Exists => format!("{base}, allow_blank: true]"),
        ValidatorKind::Rule if f.required => format!("{base}]"),
        ValidatorKind::Rule => format!("{base}, allow_nil: true]"),
    }
}

/// The text a `validates` line must contain for this validator to run at
/// all — `Templates.validates_needle/1`, what the command's currency check
/// compares against the parsed file.
pub fn validates_needle(v: &Validator) -> String {
    format!("&{}.validate/2", v.module)
}

/// Sample source value for a field — `Templates.sample_value/2`.
///
/// * **plain fields** — the happy feature scenario's `when.data`, then the
///   read model's primary example, then a type-correct default, then
///   `"sample-<field>"`.
/// * **ids and `*Id` references** — the primary example, then a type-correct
///   default. Never the scenario: a scenario's id is the `{{ generated }}`
///   sentinel, a placeholder for the system's own key, not a value.
pub fn sample_value(ctx: &Context, f: &Befield) -> String {
    if structural(f) {
        structural_source(ctx, f)
    } else {
        prose_source(ctx, f)
    }
}

/// `Templates.structural?/1` — the name is `id`, the format is `uuid`, or
/// it is a reference field (`*Id`).
fn structural(f: &Befield) -> bool {
    f.name == "id" || f.format.as_deref() == Some("uuid") || f.name.ends_with("Id")
}

fn structural_source(ctx: &Context, f: &Befield) -> String {
    match ctx.example_value(&f.name) {
        Some(source) => source,
        None => typed_default(f),
    }
}

fn prose_source(ctx: &Context, f: &Befield) -> String {
    match scenario_value(ctx, &f.name) {
        Some(value) => inspect_value(value),
        None => prose_no_scenario(ctx, f),
    }
}

fn prose_no_scenario(ctx: &Context, f: &Befield) -> String {
    match ctx.example_value(&f.name) {
        Some(source) => source,
        None => typed_default(f),
    }
}

// Typed fields get type-correct literals: the DB would reject a
// `"sample-apparatusId"` for a `:binary_id` column. The head-match order of
// `Templates.typed_default/1` is kept verbatim: `id` and `uuid` before
// `date-time`, formats before types.
fn typed_default(f: &Befield) -> String {
    if f.name == "id" {
        return "UUID.uuid4()".to_string();
    }
    match f.format.as_deref() {
        Some("uuid") => return "UUID.uuid4()".to_string(),
        Some("date-time") => return "DateTime.utc_now()".to_string(),
        _ => {}
    }
    match f.ty.as_str() {
        "integer" => "1".to_string(),
        "number" => "1.0".to_string(),
        "boolean" => "true".to_string(),
        "array" => "[]".to_string(),
        "object" => "%{}".to_string(),
        _ => inspect_value(&Value::String(format!("sample-{}", f.name))),
    }
}

/// The first scenario's `when.data[name]` — `Templates.scenario_value/2`.
/// JSON null reads as absent, matching Elixir's `get_in` returning `nil`.
fn scenario_value<'a>(ctx: &'a Context, name: &str) -> Option<&'a Value> {
    let value = ctx.scenarios.first()?.get("when")?.get("data")?.get(name)?;
    (!value.is_null()).then_some(value)
}

/// The struct literal body `key: value, ...` for all of the context's
/// fields — `Templates.struct_body/1` without the overrides map.
pub fn struct_body(ctx: &Context) -> String {
    struct_body_with(ctx, &[])
}

/// `Templates.struct_body/2` — the struct body with per-field source
/// overrides: a named field renders its override verbatim instead of its
/// sample value (the projector test seeds the id from a create event).
pub fn struct_body_with(ctx: &Context, overrides: &[(&str, &str)]) -> String {
    ctx.fields
        .iter()
        .map(
            |f| match overrides.iter().find(|(name, _)| *name == f.name) {
                Some((_, value)) => format!("{}: {value}", f.name),
                None => format!("{}: {}", f.name, sample_value(ctx, f)),
            },
        )
        .collect::<Vec<_>>()
        .join(", ")
}

/// Elixir `inspect/1` of a model value, as source — `Templates.inspect_value/1`
/// and the literal branch of `SpGen.Fixtures.materialize/2`.
pub fn inspect_value(value: &Value) -> String {
    match value {
        Value::Null => "nil".to_string(),
        Value::Bool(b) => b.to_string(),
        Value::Number(n) => {
            if n.is_i64() || n.is_u64() {
                n.to_string()
            } else if let Some(x) = n.as_f64() {
                // Elixir prints a trailing `.0` for integral floats; Rust's
                // Debug form already does.
                format!("{x:?}")
            } else {
                n.to_string()
            }
        }
        Value::String(s) => inspect_string(s),
        Value::Array(items) => format!(
            "[{}]",
            items
                .iter()
                .map(inspect_value)
                .collect::<Vec<_>>()
                .join(", ")
        ),
        Value::Object(map) => {
            // Elixir inspects maps in Erlang term order; byte-sorted string
            // keys match that order for the model's plain examples.
            let mut keys: Vec<&String> = map.keys().collect();
            keys.sort();
            let pairs: Vec<String> = keys
                .iter()
                .map(|k| format!("{} => {}", inspect_string(k), inspect_value(&map[*k])))
                .collect();
            format!("%{{{}}}", pairs.join(", "))
        }
    }
}

/// `inspect` of a binary: quoted, with Elixir's escape table (control
/// characters as `\n`-style names, the rest as `\uXXXX`, interpolation
/// escaped so the source stays inert).
pub fn inspect_string(s: &str) -> String {
    let mut out = String::with_capacity(s.len() + 2);
    out.push('"');
    let mut chars = s.chars().peekable();
    while let Some(c) = chars.next() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            '\u{0}' => out.push_str("\\0"),
            '\u{7}' => out.push_str("\\a"),
            '\u{8}' => out.push_str("\\b"),
            '\u{b}' => out.push_str("\\v"),
            '\u{c}' => out.push_str("\\f"),
            '\u{1b}' => out.push_str("\\e"),
            '#' if chars.peek() == Some(&'{') => {
                out.push_str("\\#{");
                chars.next();
            }
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn field(name: &str, ty: &str, format: Option<&str>, required: bool) -> Befield {
        Befield {
            name: name.to_string(),
            ty: ty.to_string(),
            format: format.map(str::to_string),
            description: None,
            required,
            internal: false,
        }
    }

    #[test]
    fn indents_non_empty_lines_only() {
        assert_eq!(indent("a\n\nb", 2), "  a\n\n  b");
        assert_eq!(indent("x", 4), "    x");
    }

    fn validator(name: &str, field: &str, kind: ValidatorKind) -> Validator {
        Validator {
            name: name.to_string(),
            field: field.to_string(),
            kind,
            rule: Some("the rule prose".to_string()),
            module: Context::pascal(name),
            snake: name.replace('-', "_"),
        }
    }

    #[test]
    fn the_validates_line_merges_presence_with_the_by_pairs() {
        // `Templates.validates_line/2`: presence first, then one `by:`
        // pair per guarding validator — all in ONE call, because Vex keys
        // validations per field and a second call would replace the first
        let slug = field("slug", "string", None, true);
        let unique = validator("unique-slug", "slug", ValidatorKind::Unique);
        assert_eq!(
            validates_line(&slug, std::slice::from_ref(&unique)).unwrap(),
            "validates :slug, presence: true, by: [function: &UniqueSlug.validate/2, allow_nil: true]"
        );

        // two validators, one line
        let rule = validator("at-most-one", "slug", ValidatorKind::Rule);
        assert_eq!(
            validates_line(&slug, &[unique.clone(), rule]).unwrap(),
            "validates :slug, presence: true, by: [function: &UniqueSlug.validate/2, allow_nil: true], by: [function: &AtMostOne.validate/2]"
        );

        // nothing to say: no presence, no validators
        let label = field("label", "string", None, false);
        assert_eq!(validates_line(&label, &[unique]), None);
    }

    #[test]
    fn skip_options_follow_the_pattern_and_the_requiredness() {
        let required = field("id", "string", None, true);
        let optional = field("id", "string", None, false);
        let exists = validator("widget-exists", "id", ValidatorKind::Exists);
        assert_eq!(
            validates_by_pair(&exists, &required),
            "by: [function: &WidgetExists.validate/2, allow_blank: true]",
            "the by-id lookup must never see an absent or empty id"
        );

        let rule = validator("some-rule", "id", ValidatorKind::Rule);
        assert_eq!(
            validates_by_pair(&rule, &required),
            "by: [function: &SomeRule.validate/2]",
            "enforce: true means there is no nil to skip"
        );
        assert_eq!(
            validates_by_pair(&rule, &optional),
            "by: [function: &SomeRule.validate/2, allow_nil: true]",
            "a scaffold raises on nil, so an absent optional field claims nothing"
        );

        // the needle is the pair without its skip option
        assert_eq!(
            validates_needle(&exists),
            "&WidgetExists.validate/2",
            "the currency check reads past the skip option"
        );
    }

    #[test]
    fn presence_is_required_and_not_internal() {
        let mut internal = field("id", "string", None, true);
        assert!(validates_presence(&internal));
        internal.internal = true;
        assert!(
            !validates_presence(&internal),
            "the generated id is presence's silence"
        );
    }

    #[test]
    fn validators_for_keeps_the_declaration_order_of_one_field() {
        let slug = field("slug", "string", None, true);
        let title = field("title", "string", None, true);
        let a = validator("a-rule", "slug", ValidatorKind::Rule);
        let b = validator("b-rule", "slug", ValidatorKind::Rule);
        let c = validator("c-rule", "title", ValidatorKind::Rule);
        let picked: Vec<String> = validators_for(&slug, &[a.clone(), c.clone(), b.clone()])
            .into_iter()
            .map(|v| v.name.clone())
            .collect();
        assert_eq!(
            picked,
            vec!["a-rule", "b-rule"],
            "only slug's guards, in order"
        );
        let titles: Vec<String> = validators_for(&title, &[a, b, c])
            .into_iter()
            .map(|v| v.name.clone())
            .collect();
        assert_eq!(titles, vec!["c-rule"]);
    }

    #[test]
    fn field_line_carries_enforce_for_required_fields() {
        assert_eq!(
            field_line(&field("title", "string", None, true)),
            "field :title, String.t(), enforce: true"
        );
        assert_eq!(
            field_line(&field("weight", "number", None, false)),
            "field :weight, float()"
        );
    }

    #[test]
    fn typed_defaults_follow_the_elixir_head_match_order() {
        assert_eq!(
            typed_default(&field("id", "string", None, true)),
            "UUID.uuid4()"
        );
        assert_eq!(
            typed_default(&field("coachId", "string", Some("uuid"), false)),
            "UUID.uuid4()"
        );
        assert_eq!(
            typed_default(&field("archivedAt", "string", Some("date-time"), false)),
            "DateTime.utc_now()"
        );
        assert_eq!(typed_default(&field("n", "integer", None, false)), "1");
        assert_eq!(typed_default(&field("x", "number", None, false)), "1.0");
        assert_eq!(typed_default(&field("b", "boolean", None, false)), "true");
        assert_eq!(typed_default(&field("l", "array", None, false)), "[]");
        assert_eq!(typed_default(&field("m", "object", None, false)), "%{}");
        assert_eq!(
            typed_default(&field("title", "string", None, false)),
            "\"sample-title\""
        );
    }

    #[test]
    fn elixir_inspect_quotes_and_escapes_like_the_tool() {
        assert_eq!(
            inspect_value(&Value::String("Classic Widget".into())),
            "\"Classic Widget\""
        );
        assert_eq!(inspect_value(&serde_json::json!(42)), "42");
        assert_eq!(inspect_value(&serde_json::json!(1.0)), "1.0");
        assert_eq!(inspect_value(&serde_json::json!(true)), "true");
        assert_eq!(inspect_value(&Value::Null), "nil");
        assert_eq!(
            inspect_value(&serde_json::json!(["a", "b"])),
            "[\"a\", \"b\"]"
        );
        assert_eq!(
            inspect_value(&serde_json::json!({"b": 1, "a": "x"})),
            "%{\"a\" => \"x\", \"b\" => 1}"
        );
        assert_eq!(inspect_string("a\nb\"c\\d"), "\"a\\nb\\\"c\\\\d\"");
        assert_eq!(inspect_string("#{x}"), "\"\\#{x}\"");
    }
}
