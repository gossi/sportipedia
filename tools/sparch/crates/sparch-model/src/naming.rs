//! Naming substitution for the blueprint placeholders: word splitting,
//! re-casing, and pluralizing.
//!
//! The BE engine renders blueprint templates with `<placeholder>` syntax;
//! the FE blueprints fill a typed model instead of template prose, so both
//! use the same *mechanics*: word splitting, re-casing, and the four-rule
//! pluralizer. The pluralizer must stay exactly as written — the BE router
//! and the FE mocks derive the same collection segment from it, and no
//! inflection crate may replace it (its irregular tables would diverge:
//! `person` → BE `persons`, crates `people`).

/// The casing forms the substitution engine knows. SCREAMING is the FE
/// addition (fixture consts); the BE forms carry over unchanged.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Case {
    Kebab,
    Snake,
    Camel,
    Pascal,
    Screaming,
}

/// A domain name split into words — the one representation casing renders from.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Name {
    words: Vec<String>,
}

/// Split one token into camel/Pascal parts, the semantics of the regex
/// `[A-Z]+(?![a-z])|[A-Z]?[a-z0-9]+` (Rust regexes have no look-ahead,
/// so the rule is scanned directly): an acronym run stands alone, unless a
/// lowercase tail follows, in which case the run's last letter starts that
/// word.
fn split_token(token: &str) -> Vec<String> {
    let chars: Vec<char> = token.chars().collect();
    let mut out: Vec<String> = Vec::new();
    let mut i = 0;
    while i < chars.len() {
        if chars[i].is_ascii_uppercase() {
            let mut run_end = i;
            while run_end < chars.len() && chars[run_end].is_ascii_uppercase() {
                run_end += 1;
            }
            let followed_by_lower = run_end < chars.len() && chars[run_end].is_ascii_lowercase();
            if run_end == i + 1 {
                // single capital: it opens a word that runs to the next capital
                let mut word_end = run_end;
                while word_end < chars.len() && !chars[word_end].is_ascii_uppercase() {
                    word_end += 1;
                }
                out.push(chars[i..word_end].iter().collect());
                i = word_end;
            } else if followed_by_lower {
                // acronym run + tail: the last capital belongs to the tail
                out.push(chars[i..run_end - 1].iter().collect());
                i = run_end - 1;
            } else {
                out.push(chars[i..run_end].iter().collect());
                i = run_end;
            }
        } else {
            let mut word_end = i;
            while word_end < chars.len() && !chars[word_end].is_ascii_uppercase() {
                word_end += 1;
            }
            out.push(chars[i..word_end].iter().collect());
            i = word_end;
        }
    }
    out.iter().map(|word| word.to_lowercase()).collect()
}

impl Name {
    /// Split a name into lowercase words, honoring kebab, snake, camel and
    /// Pascal casing plus acronym runs (`PublicAPI` → [public, api]).
    pub fn parse(raw: &str) -> Self {
        let words = raw
            .split(['-', '_', ' '])
            .filter(|part| !part.is_empty())
            .flat_map(split_token)
            .collect();
        Name { words }
    }

    pub fn words(&self) -> &[String] {
        &self.words
    }

    /// Assemble words directly (e.g. from a `oneOf` parameter list).
    pub fn from_words<S: AsRef<str>>(words: &[S]) -> Self {
        Name {
            words: words.iter().map(|w| w.as_ref().to_string()).collect(),
        }
    }

    pub fn render(&self, case: Case) -> String {
        let capitalize = |word: &str| -> String {
            let mut chars = word.chars();
            match chars.next() {
                Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
                None => String::new(),
            }
        };
        match case {
            Case::Kebab => self.words.join("-"),
            Case::Snake => self.words.join("_"),
            Case::Screaming => self
                .words
                .iter()
                .map(|w| w.to_uppercase())
                .collect::<Vec<_>>()
                .join("_"),
            Case::Pascal => self
                .words
                .iter()
                .map(|w| capitalize(w))
                .collect::<Vec<_>>()
                .join(""),
            Case::Camel => {
                let mut parts = self.words.iter().map(|w| capitalize(w)).collect::<Vec<_>>();
                if let Some(first) = parts.first_mut() {
                    *first = first.to_lowercase();
                }
                parts.join("")
            }
        }
    }

    /// Re-cased in one step, e.g. `Name::render_from("catalog-position", Case::Camel)`.
    pub fn render_from(raw: &str, case: Case) -> String {
        Name::parse(raw).render(case)
    }

    /// Plural words, re-cased — what `<DomainObject>s` does on the BE.
    pub fn render_plural(&self, case: Case) -> String {
        let mut name = self.clone();
        let last = name.words.len().saturating_sub(1);
        if let Some(word) = name.words.get_mut(last) {
            *word = pluralize(word);
        }
        name.render(case)
    }

    pub fn plural_kebab(&self) -> String {
        self.render_plural(Case::Kebab)
    }

    /// Singular words, re-cased — the reverse of `render_plural`, the same
    /// four rules read backward. Used by the relation naming rule: a
    /// collection property `tags` correlates with the command field
    /// `tag_ids`.
    pub fn render_singular(&self, case: Case) -> String {
        let mut name = self.clone();
        let last = name.words.len().saturating_sub(1);
        if let Some(word) = name.words.get_mut(last) {
            *word = singularize(word);
        }
        name.render(case)
    }
}

/// The inverse of the four-rule pluralizer, in the same spirit: mechanical,
/// no irregular tables. `positions` → `position`, `apparatuses` →
/// `apparatus`, `boxes` → `box`, `categories` → `category`. A word the rules
/// cannot read backward stays as written (`axis` is nobody's plural here;
/// the relation integrity checks treat a no-match as a finding, not a
/// silent guess).
pub fn singularize(text: &str) -> String {
    let lower = text.to_lowercase();
    if lower.ends_with("ies") && lower.len() > 3 {
        return format!("{}y", &text[..text.len() - 3]);
    }
    for suffix in ["ches", "shes", "xes", "zes"] {
        if lower.ends_with(suffix) && lower.len() > suffix.len() {
            return text[..text.len() - 2].to_string();
        }
    }
    // `ses` is pluralized `apparatus` + `es` (the bare-s rule); strip `es`
    if lower.ends_with("ses") && lower.len() > 3 {
        return text[..text.len() - 2].to_string();
    }
    // a bare trailing `s` that is not doubled (`class` stays)
    if lower.ends_with('s') && !lower.ends_with("ss") && lower.len() > 1 {
        return text[..text.len() - 1].to_string();
    }
    text.to_string()
}

/// The four-rule pluralizer. The `ch`/`sh` and `s`/`x`/`z` rules both append
/// `es`, so they share one arm.
pub fn pluralize(text: &str) -> String {
    let lower = text.to_lowercase();
    if lower.ends_with("ch")
        || lower.ends_with("sh")
        || matches!(
            lower.as_bytes().last(),
            Some(b's') | Some(b'x') | Some(b'z')
        )
    {
        format!("{text}es")
    } else if lower.ends_with('y')
        && lower.len() >= 2
        && !matches!(
            lower.as_bytes()[lower.len() - 2],
            b'a' | b'e' | b'i' | b'o' | b'u' | b'y'
        )
    {
        format!("{}ies", &text[..text.len() - 1])
    } else {
        format!("{text}s")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn words_split_all_casings() {
        assert_eq!(
            Name::parse("catalog-position").words,
            ["catalog", "position"]
        );
        assert_eq!(
            Name::parse("catalog_position").words,
            ["catalog", "position"]
        );
        assert_eq!(
            Name::parse("catalogPosition").words,
            ["catalog", "position"]
        );
        assert_eq!(
            Name::parse("CatalogPosition").words,
            ["catalog", "position"]
        );
        // acronym runs: JSONAPI → [json, api]
        assert_eq!(Name::parse("PublicAPI").words, ["public", "api"]);
    }

    #[test]
    fn render_recases() {
        let name = Name::parse("catalog-position");
        assert_eq!(name.render(Case::Camel), "catalogPosition");
        assert_eq!(name.render(Case::Pascal), "CatalogPosition");
        assert_eq!(name.render(Case::Kebab), "catalog-position");
        assert_eq!(name.render(Case::Snake), "catalog_position");
        assert_eq!(name.render(Case::Screaming), "CATALOG_POSITION");
    }

    #[test]
    fn pluralize_is_the_be_rule() {
        // ported from the BE naming samples: apparatus → apparatuses,
        // position → positions, box → boxes, category → categories
        assert_eq!(pluralize("position"), "positions");
        assert_eq!(pluralize("apparatus"), "apparatuses");
        assert_eq!(pluralize("box"), "boxes");
        assert_eq!(pluralize("church"), "churches");
        assert_eq!(pluralize("category"), "categories");
        assert_eq!(pluralize("day"), "days");
        assert_eq!(
            Name::parse("apparatus").render_plural(Case::Kebab),
            "apparatuses"
        );
        assert_eq!(
            Name::parse("exercise-category").render_plural(Case::Pascal),
            "ExerciseCategories"
        );
    }

    #[test]
    fn singularize_runs_the_pluralizer_backward() {
        assert_eq!(singularize("positions"), "position");
        assert_eq!(singularize("apparatuses"), "apparatus");
        assert_eq!(singularize("boxes"), "box");
        assert_eq!(singularize("churches"), "church");
        assert_eq!(singularize("categories"), "category");
        assert_eq!(singularize("days"), "day");
        assert_eq!(singularize("class"), "class");
        // every plural comes back to its word
        for word in ["position", "apparatus", "box", "church", "category", "day"] {
            assert_eq!(singularize(&pluralize(word)), word);
        }
        assert_eq!(
            Name::parse("exercise-categories").render_singular(Case::Snake),
            "exercise_category"
        );
    }
}
