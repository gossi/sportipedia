use std::io::{IsTerminal, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};

mod pages {
    include!(concat!(env!("OUT_DIR"), "/pages.rs"));
}

pub const PAGES: &[(&str, &str)] = pages::PAGES;

pub fn page_path(generator: &str) -> Option<&'static str> {
    let slug = generator.replace('_', "-");
    let candidates = [
        format!("backend/domain/{slug}.md"),
        format!("backend/web/{slug}.md"),
        format!("frontend/{slug}.md"),
    ];
    candidates
        .iter()
        .find_map(|want| PAGES.iter().find(|(path, _)| path == want))
        .map(|(path, _)| *path)
}

fn page_content(path: &str) -> Option<&'static str> {
    PAGES
        .iter()
        .find(|(p, _)| *p == path)
        .map(|(_, content)| *content)
}

pub fn be_markdown(generator: &str) -> Option<&'static str> {
    page_path(generator).and_then(page_content)
}

pub fn typescript_markdown(artifact: &str) -> Option<&'static str> {
    page_content(&format!("frontend/{artifact}.md"))
}

pub fn index() -> String {
    let mut out = String::from("man pages (rendered on demand from the registry):\n");
    for page in crate::manpage::pages() {
        let call = match page.name.as_str() {
            crate::manpage::INDEX => "sparch man".to_string(),
            name => format!("sparch man {}", name.trim_start_matches("sparch-")),
        };
        out.push_str(&format!(
            "  {:<26}{}\n",
            call,
            crate::manpage::file_name(&page.name)
        ));
    }
    out.push_str("\nblueprint docs (man/blueprints, the prose a page is built from):\n");
    for (path, _) in PAGES {
        let owner = page_owner(path).unwrap_or("(companion doc)");
        out.push_str(&format!("  {owner:<26}{path}\n"));
    }
    out
}

fn page_owner(path: &str) -> Option<&'static str> {
    let file = path.rsplit('/').next()?;
    let stem = file.strip_suffix(".md")?;
    if path.contains("/examples/")
        || stem == "_template"
        || stem == "migration"
        || stem == "README"
        || stem.ends_with("-test")
    {
        return None;
    }
    let generator = stem.replace('-', "_");
    sparch_elixir::blueprints::REGISTRY
        .iter()
        .find(|(name, _)| *name == generator)
        .map(|(name, _)| *name)
}

pub enum Format {
    Pager,
    Plain,
    Roff,
}

pub fn serve(generator: Option<&str>, target: Option<&str>, format: Format) -> i32 {
    let want = generator.unwrap_or(crate::manpage::INDEX);
    let page = match crate::manpage::page_name(want, target) {
        Ok(page) => page,
        Err(error) => {
            eprintln!("error: {error}");
            return 1;
        }
    };
    let roff = match crate::manpage::page(want, target) {
        Ok(roff) => roff,
        Err(error) => {
            eprintln!("error: {error}");
            return 1;
        }
    };
    match format {
        Format::Roff => {
            print!("{roff}");
            0
        }
        Format::Plain => {
            print!("{}", plain(&roff, &page));
            0
        }
        Format::Pager => {
            if std::io::stdout().is_terminal() && open_in_man(&roff, &page) {
                return 0;
            }
            print!("{}", plain(&roff, &page));
            0
        }
    }
}

pub fn page_text(generator: Option<&str>, target: Option<&str>) -> Result<String, String> {
    let want = generator.unwrap_or(crate::manpage::INDEX);
    let page = crate::manpage::page_name(want, target)?;
    let roff = crate::manpage::page(want, target)?;
    Ok(plain(&roff, &page))
}

fn plain(roff: &str, page: &str) -> String {
    if let Some(text) = through_groff(roff) {
        return clean(&text);
    }
    if let Some(text) = through_man(roff, page) {
        return clean(&text);
    }
    roff.to_string()
}

/// Both renderers mark bold and italic inside the text stream: groff and mandoc
/// overstrike with backspaces, man-db's groff additionally colors with SGR
/// sequences even when its output is a pipe. A page read as text wants neither.
fn clean(text: &str) -> String {
    strip_overstrike(&strip_sgr(text))
}

fn strip_sgr(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut chars = text.chars().peekable();
    while let Some(ch) = chars.next() {
        if ch != '\u{1b}' {
            out.push(ch);
            continue;
        }
        // A control sequence is ESC, '[', parameter and intermediate bytes, then
        // one final byte in 0x40..=0x7E. Anything else after ESC is left out too,
        // so a truncated sequence cannot leak a control code into the text.
        if chars.peek() == Some(&'[') {
            chars.next();
            for next in chars.by_ref() {
                if ('\u{40}'..='\u{7e}').contains(&next) {
                    break;
                }
            }
        }
    }
    out
}

fn through_groff(roff: &str) -> Option<String> {
    let mut child = Command::new("groff")
        .args(["-mandoc", "-Tutf8"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()?;
    if let Some(mut stdin) = child.stdin.take() {
        let _ = stdin.write_all(roff.as_bytes());
    }
    let out = child.wait_with_output().ok()?;
    match out.status.success() {
        true => Some(String::from_utf8_lossy(&out.stdout).to_string()),
        false => None,
    }
}

fn through_man(roff: &str, page: &str) -> Option<String> {
    let root = stage(roff, page)?;
    let out = Command::new("man")
        .arg("-M")
        .arg(&root)
        .args(["-S", "1", page])
        .env("PAGER", "cat")
        .output()
        .ok()?;
    let _ = std::fs::remove_dir_all(&root);
    match out.status.success() {
        true => Some(String::from_utf8_lossy(&out.stdout).to_string()),
        false => None,
    }
}

fn open_in_man(roff: &str, page: &str) -> bool {
    let Some(root) = stage(roff, page) else {
        return false;
    };
    let file = root.join("man1").join(format!("{page}.1"));
    let typed = Command::new("man")
        .arg("-l")
        .arg(&file)
        .status()
        .or_else(|_| {
            Command::new("man")
                .arg("-M")
                .arg(&root)
                .args(["-S", "1", page])
                .status()
        })
        .map(|status| status.success());
    let _ = std::fs::remove_dir_all(&root);
    typed.unwrap_or(false)
}

fn stage(roff: &str, page: &str) -> Option<PathBuf> {
    let root = std::env::temp_dir().join(format!("sparch-man-{}-{page}", std::process::id()));
    let dir = root.join("man1");
    std::fs::create_dir_all(&dir).ok()?;
    std::fs::write(dir.join(format!("{page}.1")), roff).ok()?;
    Some(root)
}

fn strip_overstrike(text: &str) -> String {
    let chars: Vec<char> = text.chars().collect();
    let mut out = String::with_capacity(text.len());
    let mut index = 0;
    while index < chars.len() {
        let next = chars.get(index + 1).copied();
        let after = chars.get(index + 2).copied();
        match (next, after) {
            (Some('\u{8}'), Some(letter)) if letter == chars[index] || chars[index] == '_' => {
                out.push(letter);
                index += 3;
            }
            (Some('\u{8}'), _) => index += 2,
            _ => {
                out.push(chars[index]);
                index += 1;
            }
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn overstrike_becomes_plain_text() {
        assert_eq!(strip_overstrike("NA\u{8}AM\u{8}ME"), "NAME");
        assert_eq!(strip_overstrike("_\u{8}x _\u{8}y"), "x y");
        assert_eq!(strip_overstrike("keep"), "keep");
    }

    #[test]
    fn control_sequences_are_dropped() {
        // groff colors a page it is writing to a pipe, and man-db passes that
        // through, so the plain face has to remove it.
        assert_eq!(strip_sgr("\u{1b}[1mNAME\u{1b}[0m"), "NAME");
        assert_eq!(strip_sgr("\u{1b}[4mT\u{1b}[24m(1)"), "T(1)");
        assert_eq!(strip_sgr("keep"), "keep");
        assert_eq!(clean("\u{1b}[1mNA\u{8}AM\u{8}ME\u{1b}[0m"), "NAME");
    }
}
