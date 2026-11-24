use std::io::IsTerminal;
use std::path::PathBuf;
use std::process::Command;

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
            print!("{}", crate::plaintext::render(&roff));
            0
        }
        Format::Pager => {
            if std::io::stdout().is_terminal() && open_in_man(&roff, &page) {
                return 0;
            }
            print!("{}", crate::plaintext::render(&roff));
            0
        }
    }
}

pub fn page_text(generator: Option<&str>, target: Option<&str>) -> Result<String, String> {
    let want = generator.unwrap_or(crate::manpage::INDEX);
    // Resolved for its error: an unknown generator must answer here, and the
    // page name itself only mattered when a formatter was in the loop.
    crate::manpage::page_name(want, target)?;
    let roff = crate::manpage::page(want, target)?;
    Ok(crate::plaintext::render(&roff))
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
