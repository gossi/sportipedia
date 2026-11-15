//! Splice-based text edits — the write half of the verdict: nothing is
//! re-printed, only ranges of original text are left untouched while new
//! fragments are inserted at computed offsets.
//!
//! `--force` adds the one other operation the model needs: *replacing* the
//! span of an existing generated unit with its fresh rendering. The
//! replacement is still surgical — a range of bytes owned by one
//! declaration (plus its directly-preceding comment block), never a
//! reprint of the file.

/// An ordered set of insertions and replacements into one file, applied
/// back-to-front so earlier offsets stay valid.
#[derive(Default)]
pub struct Splices(Vec<(u32, u32, String)>);

impl Splices {
    pub fn insert(&mut self, offset: u32, text: impl Into<String>) {
        self.0.push((offset, offset, text.into()));
    }

    /// Replace `from..to` with `text`.
    pub fn replace(&mut self, from: u32, to: u32, text: impl Into<String>) {
        self.0.push((from, to, text.into()));
    }

    pub fn is_empty(&self) -> bool {
        self.0.is_empty()
    }

    pub fn apply(&self, source: &str) -> String {
        let mut edits = self.0.clone();
        edits.sort_by_key(|(start, _, _)| *start);
        let mut result = source.to_string();
        for (start, end, text) in edits.into_iter().rev() {
            let from = (start as usize).min(result.len());
            let to = (end as usize).min(result.len());
            result.replace_range(from..to, &text);
        }
        result
    }
}

/// The comment lines directly above `start`, with no blank line between:
/// a unit's JSDoc header belongs to it, and a `--force` replacement that
/// left the old comment behind would double it.
pub fn extend_over_leading_comments(text: &str, start: usize) -> usize {
    let mut pos = start;
    loop {
        if pos == 0 {
            break;
        }
        // the line above `pos` (pos sits on a line start)
        let prev_end = pos - 1; // the '\n' before pos
        let prev_start = text[..prev_end].rfind('\n').map(|i| i + 1).unwrap_or(0);
        let above = text[prev_start..prev_end].trim_end_matches('\r');
        let p = above.trim();
        if p.is_empty() {
            break;
        }
        if p.starts_with("//") || p.starts_with("/*") || p.starts_with('*') || p.starts_with("*/") {
            pos = prev_start;
        } else {
            break;
        }
    }
    pos
}

/// The span of a `test('<title>', …)` call statement, including its
/// terminating semicolon — the replacement range for force-rewritten
/// truth tables.
pub fn test_statement_range(text: &str, title: &str) -> Option<(usize, usize)> {
    let start = text
        .find(&format!("test('{title}'"))
        .or_else(|| text.find(&format!("test(\"{title}\"")))?;
    let open = text[start..].find('(')? + start;
    let mut depth = 0usize;
    let mut close = None;
    for (i, byte) in text.as_bytes()[open..].iter().enumerate() {
        match byte {
            b'(' => depth += 1,
            b')' => {
                depth -= 1;
                if depth == 0 {
                    close = Some(open + i);
                    break;
                }
            }
            _ => {}
        }
    }
    let mut end = close? + 1;
    if text[end..].starts_with(';') {
        end += 1;
    }
    Some((start, end))
}

/// Find the byte offset just past the end of the line containing `needle`
/// (first occurrence), for anchor-based insertions like the schema
/// registration lines.
pub fn after_line(text: &str, needle: &str) -> Option<usize> {
    let at = text.find(needle)?;
    let rest = &text[at..];
    let line_end = rest.find('\n').map(|i| at + i).unwrap_or(text.len());
    Some(line_end)
}

/// Like `after_line` but anchored at the *last* occurrence — the sibling
/// pattern: register the next citizen after the one before it.
pub fn after_last_line(text: &str, needle: &str) -> Option<usize> {
    let at = text.rfind(needle)?;
    let line_end = text[at..].find('\n').map(|i| at + i).unwrap_or(text.len());
    Some(line_end)
}

/// The span of the bracket list introduced by `anchor` (which must end in
/// `[` or `{`), as (first_inner, closer) offsets, scanning forward with
/// simple bracket counting. String contents are assumed not to carry
/// unbalanced brackets (true for every host we write into: identifiers and
/// member accesses only).
pub fn array_span(text: &str, anchor: &str) -> Option<(usize, usize)> {
    let open = text.find(anchor)? + anchor.len();
    let (open_ch, close_ch) = match text.as_bytes().get(open.wrapping_sub(1))? {
        b'[' => (b'[', b']'),
        b'{' => (b'{', b'}'),
        _ => return None,
    };
    let mut depth = 1usize;
    let bytes = text.as_bytes();
    let mut i = open;
    while i < bytes.len() {
        if bytes[i] == open_ch {
            depth += 1;
        } else if bytes[i] == close_ch {
            depth -= 1;
            if depth == 0 {
                return Some((open, i));
            }
        }
        i += 1;
    }
    None
}

/// True when the bracket list introduced by `anchor` (ending in `[` or
/// `{`) already carries `member` as one of its comma-separated parts.
pub fn array_has_member(text: &str, anchor: &str, member: &str) -> bool {
    let Some((open, close)) = array_span(text, anchor) else {
        return false;
    };
    text[open..close]
        .split(',')
        .any(|part| part.trim() == member)
}

/// The splice to add `member` to the array at `anchor`.
pub fn insert_into_array(text: &str, anchor: &str, member: &str) -> Option<(u32, String)> {
    let (open, close) = array_span(text, anchor)?;
    if text[open..close].trim().is_empty() {
        return Some((open as u32, member.to_string()));
    }
    // append after the last element: rewind from the closer to the last
    // non-whitespace byte
    let last = text[..close].trim_end().len();
    Some((last as u32, format!(", {member}")))
}

/// Locate the `export { … } from '<source>'` block of a barrel file:
/// (first_inner, closer) offsets of the braces.
pub fn export_block_span(text: &str, from_source: &str) -> Option<(usize, usize)> {
    let mut search_from = 0;
    while let Some(relative) = text[search_from..].find("export {") {
        let open_abs = search_from + relative;
        if let Some((inner, close_relative)) = array_span(&text[open_abs..], "export {") {
            let close = open_abs + close_relative;
            // `close` is the offset of the `}` itself — the source follows
            let tail = text[close + 1..].trim_start();
            if tail.starts_with(&format!("from '{from_source}'")) {
                return Some((open_abs + inner, close));
            }
        }
        search_from = open_abs + "export {".len();
    }
    None
}

pub fn block_has_member(text: &str, from_source: &str, member: &str) -> bool {
    let Some((open, close)) = export_block_span(text, from_source) else {
        return false;
    };
    text[open..close]
        .split(',')
        .any(|part| part.trim() == member)
}

/// Splice to add `member` to the export block of `from_source`.
pub fn insert_into_block(text: &str, from_source: &str, member: &str) -> Option<(u32, String)> {
    let (open, close) = export_block_span(text, from_source)?;
    if text[open..close].trim().is_empty() {
        return Some((open as u32, format!(" {member} ")));
    }
    let last = text[..close].trim_end().len();
    Some((last as u32, format!(", {member}")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn replace_swaps_a_range() {
        let mut splices = Splices::default();
        splices.replace(1, 4, "X");
        assert_eq!(splices.apply("abccd"), "aXd");
    }

    #[test]
    fn comment_extension_walks_contiguous_comment_lines() {
        let text = "// above\n\n/**\n * doc\n */\nexport function f() {}\n";
        let start = text.find("export").unwrap();
        // stops at the blank line above, takes the jsdoc block
        assert_eq!(
            extend_over_leading_comments(text, start),
            text.find("/**").unwrap()
        );
        let direct = "/** doc */\nexport const A = 1;\n";
        assert_eq!(
            extend_over_leading_comments(direct, direct.find("export").unwrap()),
            0
        );
    }

    #[test]
    fn test_statement_range_covers_the_call() {
        let text = "setup();\ntest('canX()', () => {\n  expect(1).toBe(1);\n});\nafter();\n";
        let (start, end) = test_statement_range(text, "canX()").unwrap();
        assert_eq!(
            &text[start..end],
            "test('canX()', () => {\n  expect(1).toBe(1);\n});"
        );
    }

    #[test]
    fn export_blocks_are_source_scoped() {
        let text = "export {\n  A, B\n} from './fixtures/positions';\nexport {\n  C\n} from './queries/positions';\n";
        assert!(block_has_member(text, "./fixtures/positions", "A"));
        assert!(!block_has_member(text, "./fixtures/positions", "C"));
        assert!(block_has_member(text, "./queries/positions", "C"));
        let (offset, inserted) = insert_into_block(text, "./fixtures/positions", "D").unwrap();
        let mut splices = Splices::default();
        splices.insert(offset, inserted);
        let merged = splices.apply(text);
        assert!(merged.contains("A, B, D"));
        assert!(merged.contains("  C\n"));
    }

    #[test]
    fn multiline_blocks_resolve_the_right_source() {
        let text = "export {\n  UNICYCLE_RIDING,\n  POSITIONS\n} from './fixtures/positions';\n\nexport {\n  makePositionResponse\n} from './queries/positions';\n";
        assert!(block_has_member(
            text,
            "./fixtures/positions",
            "UNICYCLE_RIDING"
        ));
        assert!(
            export_block_span(text, "./queries/positions").is_some(),
            "second block must resolve"
        );
        assert!(!block_has_member(
            text,
            "./fixtures/positions",
            "makePositionResponse"
        ));
    }

    #[test]
    fn splices_apply_back_to_front() {
        let mut splices = Splices::default();
        splices.insert(1, "X");
        splices.insert(0, "Y");
        assert_eq!(splices.apply("abc"), "YaXbc");
    }

    #[test]
    fn array_membership_and_insert() {
        let text = "schema.registerResources([positionSchema]);";
        assert!(array_has_member(
            text,
            "registerResources([",
            "positionSchema"
        ));
        assert!(!array_has_member(
            text,
            "registerResources([",
            "apparatusSchema"
        ));
        let (offset, inserted) =
            insert_into_array(text, "registerResources([", "apparatusSchema").unwrap();
        let mut splices = Splices::default();
        splices.insert(offset, inserted);
        assert_eq!(
            splices.apply(text),
            "schema.registerResources([positionSchema, apparatusSchema]);"
        );
    }

    #[test]
    fn empty_array_inserts_bare() {
        let text = "schema.registerResources([]);";
        let (offset, inserted) =
            insert_into_array(text, "registerResources([", "positionSchema").unwrap();
        let mut splices = Splices::default();
        splices.insert(offset, inserted);
        assert_eq!(
            splices.apply(text),
            "schema.registerResources([positionSchema]);"
        );
    }
}
