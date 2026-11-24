//! The text face of a manual page. sparch writes roff, and whoever reads a page
//! as text gets this rendering of it, not the output of whichever formatter
//! happens to be installed. groff justifies, hyphenates, colors a pipe and
//! decodes its input by locale, while mandoc does none of those, so the same
//! page read through each came out as two different texts. The content is ours,
//! so the text stays ours here.
//!
//! Only the control lines `crate::manpage` and clap_mangen emit are interpreted,
//! and an unknown one is skipped: inventing layout for it would repeat the
//! mistake this module exists to end.

/// Body text sits under its heading, and a section opens after a blank line.
const INDENT: usize = 4;

/// Which block the text lines after a control line belong to.
#[derive(PartialEq, Clone, Copy)]
enum Block {
    /// Ordinary body text, also what a heading opens and what follows a term.
    Body,
    /// `.TP`: the next line is the term, later lines its description.
    Term,
    /// `.IP`: the next lines are one bullet item.
    Bullet,
}

/// Render roff into the text a page says. Sentences stay on one line: where a
/// line breaks is a formatter's choice, and unwrapped prose is what lets a page
/// be compared by content.
pub fn render(roff: &str) -> String {
    let mut out = String::new();
    let mut block = Block::Body;
    let mut shift = 0;
    // A heading's own body belongs under it without a gap, and so do the items
    // of one list. Everything else opens after a blank line.
    let mut tight = false;

    for raw in roff.lines() {
        let line = raw.trim_end();
        if line.is_empty() {
            continue;
        }
        if let Some(control) = line.strip_prefix('.') {
            let (name, args) = split(control);
            match name {
                "SH" | "SS" => {
                    gap(&mut out, !tight);
                    out.push_str(&format!("{}\n", decode(args.trim_matches('"'))));
                    block = Block::Body;
                    shift = 0;
                    tight = true;
                }
                "TP" => {
                    gap(&mut out, !tight);
                    block = Block::Term;
                    tight = false;
                }
                "IP" => {
                    // Consecutive items of one list stay tight under each other,
                    // and so does the first item of a list an `.RS` just opened
                    // under its introducing line.
                    gap(&mut out, block != Block::Bullet && !tight && shift == 0);
                    block = Block::Bullet;
                }
                "PP" => {
                    gap(&mut out, !tight);
                    block = Block::Body;
                    tight = false;
                }
                // `.RS 14` and `.RE` nest the body, which is how a list of
                // possible values sits further in than the line that introduces it.
                "RS" => shift += INDENT,
                "RE" => shift = shift.saturating_sub(INDENT),
                // `.TH` is the banner a formatter draws, and `.br` is a break
                // inside a block whose lines this renderer keeps separate.
                _ => {}
            }
            continue;
        }

        let text = decode(line);
        if text.trim().is_empty() {
            continue;
        }
        gap(&mut out, false);
        let prefix = match block {
            Block::Bullet => format!("{}- ", pad(INDENT + shift)),
            _ => pad(INDENT + shift),
        };
        out.push_str(&format!("{prefix}{text}\n"));
        if block == Block::Term {
            block = Block::Body;
        }
        tight = false;
    }
    out
}

fn pad(indent: usize) -> String {
    " ".repeat(indent)
}

/// One blank line between blocks, never at the top and never twice.
fn gap(out: &mut String, want: bool) {
    if want && !out.is_empty() && !out.ends_with("\n\n") {
        out.push('\n');
    }
}

fn split(control: &str) -> (&str, &str) {
    match control.split_once(char::is_whitespace) {
        Some((name, args)) => (name, args),
        None => (control, ""),
    }
}

/// Turn one roff text line into the characters it says.
fn decode(line: &str) -> String {
    let mut out = String::with_capacity(line.len());
    let mut chars = line.chars().peekable();
    while let Some(ch) = chars.next() {
        if ch != '\\' {
            out.push(ch);
            continue;
        }
        match chars.next() {
            // A font escape styles without adding a character: `\fB`, `\fI`, `\fR`.
            Some('f') => {
                chars.next();
            }
            Some('-') => out.push('-'),
            Some('\'') | Some('`') => out.push('\''),
            Some(' ') => out.push(' '),
            // `\&`, `\.` and `\!` hold a place in roff and say nothing.
            Some('&') | Some('.') | Some('!') => {}
            Some('\\') => out.push('\\'),
            Some('[') => out.push_str(&code_point(&take_to(&mut chars, ']'))),
            Some('(') => out.push_str(&code_point(&take_n(&mut chars, 2))),
            Some(other) => out.push(other),
            None => {}
        }
    }
    out
}

fn take_to(chars: &mut std::iter::Peekable<std::str::Chars>, stop: char) -> String {
    chars.by_ref().take_while(|ch| *ch != stop).collect()
}

fn take_n(chars: &mut std::iter::Peekable<std::str::Chars>, n: usize) -> String {
    chars.by_ref().take(n).collect()
}

/// `\[u00E9]`, `\[bu]`, `\(bu` and `\(em` in the characters they mean. Dashes and
/// bullets all reach the text as a plain `-`, which is the spelling every
/// formatter agrees on.
fn code_point(name: &str) -> String {
    if let Some(hex) = name.strip_prefix('u') {
        return u32::from_str_radix(hex, 16)
            .ok()
            .and_then(char::from_u32)
            .map(String::from)
            .unwrap_or_default();
    }
    match name {
        "em" | "en" | "hy" | "mi" | "bu" => "-",
        "q" | "dq" => "\"",
        "lq" | "rq" => "'",
        _ => "",
    }
    .to_string()
}

#[cfg(test)]
mod tests {
    use super::render;

    #[test]
    fn a_heading_and_its_body() {
        let roff = ".TH \"SPARCH\" \"1\" \"\" \"sparch 0.1.0\" \"\"\n.SH NAME\nsparch \\- the generators' tool\n.SH SYNOPSIS\nsparch [options] <subcommands>\n";
        assert_eq!(
            render(roff),
            "NAME\n    sparch - the generators' tool\n\nSYNOPSIS\n    sparch [options] <subcommands>\n"
        );
    }

    #[test]
    fn quoted_headings_and_terms() {
        let roff = ".SH \"SEE ALSO\"\nsparch(1)\n.SH OPTIONS\n.TP\n\\fB\\-\\-root\\fR \\fI<ROOT>\\fR\nrepo root\n.TP\n\\fB\\-\\-model\\fR \\fI<MODEL>\\fR\nmodel root\n";
        assert_eq!(
            render(roff),
            "SEE ALSO\n    sparch(1)\n\nOPTIONS\n    --root <ROOT>\n    repo root\n\n    --model <MODEL>\n    model root\n"
        );
    }

    #[test]
    fn bullets_carry_their_text_on_the_same_line() {
        let roff = ".SH \"Left to you\"\n.IP \\[bu] 2\nThe table: mix ecto.gen.migration.\n.IP \\[bu] 2\nA custom changeset.\n";
        assert_eq!(
            render(roff),
            "Left to you\n    - The table: mix ecto.gen.migration.\n    - A custom changeset.\n"
        );
    }

    #[test]
    fn a_nested_list_sits_further_in() {
        let roff = ".TP\n\\fB\\-\\-template\\fR \\fI<TEMPLATE>\\fR\nwhat the operation does\n.br\nPossible values:\n.RS 14\n.IP \\(bu 2\ncreate\n.RE\n";
        assert_eq!(
            render(roff),
            "    --template <TEMPLATE>\n    what the operation does\n    Possible values:\n        - create\n"
        );
    }

    #[test]
    fn a_code_point_reaches_the_text_as_that_character() {
        let roff = ".SH DESCRIPTION\nTrès \\[u00E9] and a dash - as spelled.\n";
        assert_eq!(
            render(roff),
            "DESCRIPTION\n    Très é and a dash - as spelled.\n"
        );
    }

    #[test]
    fn unknown_control_lines_are_skipped() {
        let roff = ".noHY\n.SH NAME\np \\- tool\n";
        assert_eq!(render(roff), "NAME\n    p - tool\n");
    }
}
