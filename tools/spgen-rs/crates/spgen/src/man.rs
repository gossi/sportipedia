use std::io::{IsTerminal, Write};
use std::path::PathBuf;
use std::process::{Command, Stdio};

mod pages {
    include!(concat!(env!("OUT_DIR"), "/pages.rs"));
}

mod roff_pages {
    include!(concat!(env!("OUT_DIR"), "/roff.rs"));
}

pub const PAGES: &[(&str, &str)] = pages::PAGES;

pub const ROFF_PAGES: &[(&str, &str)] = roff_pages::ROFF_PAGES;

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
    let mut out = String::from("man pages (man/roff, embedded at build time):\n");
    for page in crate::manpage::pages() {
        let call = match page.name.as_str() {
            crate::manpage::INDEX => "spgen man".to_string(),
            name => format!("spgen man {}", name.trim_start_matches("spgen-")),
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
    spgen_elixir::blueprints::REGISTRY
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
    let Some(roff) = embedded(&page) else {
        eprintln!(
            "error: no embedded man page '{page}'; run `spgen man --write` and rebuild spgen"
        );
        return 1;
    };
    match format {
        Format::Roff => {
            print!("{roff}");
            0
        }
        Format::Plain => {
            print!("{}", plain(roff, &page));
            0
        }
        Format::Pager => {
            if std::io::stdout().is_terminal() && open_in_man(roff, &page) {
                return 0;
            }
            print!("{}", plain(roff, &page));
            0
        }
    }
}

pub fn page_text(generator: Option<&str>, target: Option<&str>) -> Result<String, String> {
    let page = crate::manpage::page_name(generator.unwrap_or(crate::manpage::INDEX), target)?;
    let roff = embedded(&page)
        .ok_or_else(|| format!("no embedded man page '{page}'; run `spgen man --write`"))?;
    Ok(plain(roff, &page))
}

fn embedded(page: &str) -> Option<&'static str> {
    ROFF_PAGES
        .iter()
        .find(|(name, _)| *name == page)
        .map(|(_, roff)| *roff)
}

fn plain(roff: &str, page: &str) -> String {
    if let Some(text) = through_groff(roff) {
        return strip_overstrike(&text);
    }
    if let Some(text) = through_man(roff, page) {
        return strip_overstrike(&text);
    }
    roff.to_string()
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
    let root = std::env::temp_dir().join(format!("spgen-man-{}-{page}", std::process::id()));
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
    fn every_generated_page_is_embedded() {
        for page in crate::manpage::pages() {
            assert!(
                embedded(&page.name).is_some(),
                "man/roff/{}.1 is not embedded; run `spgen man --write` and rebuild",
                page.name
            );
        }
    }
}
