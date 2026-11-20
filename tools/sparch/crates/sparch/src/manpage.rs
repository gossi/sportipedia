use std::path::Path;

use clap::builder::PossibleValuesParser;
use clap::{Arg, Args, Command, CommandFactory};
use clap_mangen::Man;
use pulldown_cmark::{Event, HeadingLevel, Options, Parser, Tag, TagEnd};
use roff::{Roff, bold, italic, roman};

use crate::cli::{Cli, GenerateArgs};
use sparch_elixir::blueprints as be;
use sparch_elixir::suites::Suite;
use sparch_typescript::blueprints as fe;

pub const INDEX: &str = "sparch";
pub const SECTION: &str = "1";
pub const ROFF_DIR: &str = "tools/sparch/man/roff";

const SOURCE: &str = concat!("sparch ", env!("CARGO_PKG_VERSION"));
const PREAMBLE: &str = ".ie \\n(.g .ds Aq \\(aq\n.el .ds Aq '\n";
const NO_ARGS: [&str; 0] = [];
const BULLET: &str = r"\[bu]";
const BE_SUITES: [Suite; 3] = [Suite::Operation, Suite::Endpoint, Suite::Feature];
const OPTION_IDS: [&str; 7] = [
    "root",
    "model",
    "subdomain",
    "composite",
    "constituent",
    "dry_run",
    "force",
];

pub struct Page {
    pub name: String,
    pub roff: String,
}

struct Facts {
    page: String,
    about: Option<&'static str>,
    element: String,
    binding: String,
    files: Vec<(&'static str, &'static str)>,
    template: Option<(Vec<&'static str>, bool)>,
    markdown: Option<&'static str>,
    suites: Vec<&'static str>,
}

pub fn pages() -> Vec<Page> {
    let mut pages = vec![index_page()];
    for generator in be::GENERATOR_ORDER {
        pages.push(be_page(generator));
    }
    for (artifact, _) in fe::artifacts() {
        pages.push(fe_page(artifact));
    }
    pages
}

pub fn page(generator: &str, target: Option<&str>) -> Result<String, String> {
    resolve(generator, target).map(|page| page.roff)
}

pub fn page_name(generator: &str, target: Option<&str>) -> Result<String, String> {
    resolve(generator, target).map(|page| page.name)
}

pub fn file_name(page: &str) -> String {
    format!("{page}.{SECTION}")
}

pub fn write(dir: &Path) -> Result<Vec<String>, String> {
    std::fs::create_dir_all(dir)
        .map_err(|error| format!("cannot create {}: {error}", dir.display()))?;
    let mut written = Vec::new();
    for page in pages() {
        let path = dir.join(file_name(&page.name));
        std::fs::write(&path, &page.roff)
            .map_err(|error| format!("cannot write {}: {error}", path.display()))?;
        written.push(path.display().to_string());
    }
    Ok(written)
}

fn resolve(generator: &str, target: Option<&str>) -> Result<Page, String> {
    if generator == INDEX {
        return Ok(index_page());
    }
    let wants_be = matches!(target, None | Some("elixir"));
    let wants_fe = matches!(target, None | Some("typescript"));
    let has_be = be::GENERATOR_ORDER.contains(&generator);
    let has_fe = fe::artifacts().iter().any(|(id, _)| *id == generator);
    match (wants_be && has_be, wants_fe && has_fe) {
        (true, false) => Ok(be_page(generator)),
        (false, true) => Ok(fe_page(generator)),
        (true, true) => Err(format!(
            "'{generator}' has a page in both languages, so pass --target elixir or typescript"
        )),
        (false, false) => Err(format!(
            "no page for '{generator}'; `sparch man` answers generators and artifacts, \
             never suite pages"
        )),
    }
}

fn be_page(generator: &str) -> Page {
    let head = be::blueprint_for(generator);
    let kinds = match head {
        Some(blueprint) => blueprint
            .source_kinds()
            .iter()
            .map(|kind| kind.as_str())
            .collect(),
        None => crate::arch::be_rule(generator)
            .map(|rule| rule.kinds.to_vec())
            .unwrap_or_default(),
    };
    let element = placeholder(&kinds);
    let facts = Facts {
        page: format!("sparch-{generator}"),
        about: head.and_then(|blueprint| blueprint.description()),
        element: element.clone(),
        binding: format!("mix sp.gen.{generator} [options] <{element}>"),
        files: be_files(generator),
        template: head
            .filter(|blueprint| !blueprint.is_fixed())
            .map(|blueprint| {
                (
                    blueprint
                        .operations()
                        .iter()
                        .map(|operation| operation.as_str())
                        .collect(),
                    blueprint.optional_template(),
                )
            }),
        markdown: crate::man::be_markdown(generator),
        suites: BE_SUITES
            .iter()
            .filter(|suite| suite.members().contains(&generator))
            .map(Suite::as_str)
            .collect(),
    };
    let roff = assemble(&facts);
    Page {
        name: facts.page,
        roff,
    }
}

fn fe_page(artifact: &str) -> Page {
    let shares_a_name = be::GENERATOR_ORDER.contains(&artifact);
    let page = match shares_a_name {
        true => format!("sparch-{artifact}-typescript"),
        false => format!("sparch-{artifact}"),
    };
    let mut suites: Vec<&'static str> = fe::suites()
        .into_iter()
        .filter(|(_, members)| members.contains(&artifact))
        .map(|(group, _)| group)
        .collect();
    suites.push(fe::FEATURE);
    let facts = Facts {
        page,
        about: Some(fe::shortdoc(artifact)),
        element: "READ-MODEL".to_string(),
        binding: format!("pnpm spgen {artifact} <read-model>"),
        files: fe::generated_files(artifact),
        template: None,
        markdown: crate::man::typescript_markdown(artifact),
        suites,
    };
    let roff = assemble(&facts);
    Page {
        name: facts.page,
        roff,
    }
}

fn placeholder(kinds: &[&'static str]) -> String {
    match kinds.is_empty() {
        true => "ELEMENT".to_string(),
        false => kinds
            .iter()
            .map(|kind| kind.to_uppercase())
            .collect::<Vec<_>>()
            .join("|"),
    }
}

fn assemble(facts: &Facts) -> String {
    let mut cmd = Command::new(facts.page.clone())
        .override_usage(facts.binding.clone())
        .args(standard_options())
        .arg(element_arg(&facts.element));
    if let Some(about) = facts.about {
        cmd = cmd.about(about);
    }
    if let Some((values, optional)) = &facts.template {
        cmd = cmd.arg(template_arg(values, *optional));
    }
    let man = Man::new(cmd);
    let mut out = title_line(&facts.page);
    out.push_str(&clap_section(|w| man.render_name_section(w)));
    out.push_str(&clap_section(|w| man.render_synopsis_section(w)));
    out.push_str(&description(facts.markdown, facts.about.unwrap_or("")));
    out.push_str(&generated_files(&facts.files));
    out.push_str(&clap_section(|w| man.render_options_section(w)));
    out.push_str(&see_also(&facts.suites));
    out
}

fn standard_options() -> Vec<Arg> {
    let face = GenerateArgs::augment_args(Command::new("generate"));
    OPTION_IDS
        .iter()
        .filter_map(|id| face.get_arguments().find(|arg| arg.get_id() == *id))
        .cloned()
        .collect()
}

fn element_arg(value_name: &str) -> Arg {
    let face = GenerateArgs::augment_args(Command::new("generate"));
    let help = face
        .get_arguments()
        .find(|arg| arg.get_id() == "element")
        .and_then(|arg| arg.get_help())
        .map(ToString::to_string);
    let arg = Arg::new("element")
        .value_name(value_name.to_string())
        .required(true)
        .num_args(1);
    match help {
        Some(help) => arg.help(help),
        None => arg,
    }
}

fn template_arg(values: &[&'static str], optional: bool) -> Arg {
    let mut help = format!("what the operation does: {}", values.join("|"));
    if optional {
        help.push_str(" (optional: the model declares the operation for this element)");
    }
    Arg::new("template")
        .long("template")
        .value_name("TEMPLATE")
        .num_args(1)
        .value_parser(PossibleValuesParser::new(values.iter().copied()))
        .help(help)
}

fn title_line(page: &str) -> String {
    format!(
        ".TH \"{}\" \"{SECTION}\" \"\" \"{SOURCE}\" \"\"\n",
        page.to_uppercase()
    )
}

fn clap_section(render: impl Fn(&mut dyn std::io::Write) -> std::io::Result<()>) -> String {
    let mut buffer: Vec<u8> = Vec::new();
    render(&mut buffer).expect("writing to a Vec cannot fail");
    String::from_utf8(buffer)
        .expect("clap_mangen renders utf8")
        .replace(PREAMBLE, "")
        .replace(r"\*(Aq", "'")
}

fn be_files(generator: &str) -> Vec<(&'static str, &'static str)> {
    let mut files: Vec<(&'static str, &'static str)> = Vec::new();
    for module in be::generator_modules(generator) {
        for file in module.generated_files() {
            if !files.iter().any(|(path, _)| *path == file.0) {
                files.push(file);
            }
        }
    }
    files
}

fn generated_files(files: &[(&'static str, &'static str)]) -> String {
    if files.is_empty() {
        return String::new();
    }
    let mut roff = Roff::new();
    roff.control("SS", ["Generated files"]);
    for (path, note) in files {
        roff.control("IP", [BULLET, "2"]);
        roff.text([roman(format!("{path} ({note})"))]);
    }
    roff.to_roff()
}

fn description(markdown: Option<&'static str>, fallback: &str) -> String {
    let head = Roff::new().control("SH", ["DESCRIPTION"]).to_roff();
    match markdown {
        Some(doc) => format!("{head}{}", markdown_to_roff(doc)),
        None if fallback.is_empty() => head,
        None => format!("{head}{}", Roff::new().text([roman(fallback)]).to_roff()),
    }
}

fn see_also(suites: &[&'static str]) -> String {
    let mut roff = Roff::new();
    roff.control("SH", ["SEE ALSO"])
        .text([roman(format!("{INDEX}({SECTION})"))]);
    if !suites.is_empty() {
        roff.text([roman(format!("suites: {}", suites.join(", ")))]);
    }
    roff.to_roff()
}

fn index_page() -> Page {
    let man = Man::new(Cli::command());
    let mut roff = title_line(INDEX);
    roff.push_str(&clap_section(|w| man.render_name_section(w)));
    roff.push_str(&clap_section(|w| man.render_synopsis_section(w)));
    roff.push_str(&clap_section(|w| man.render_description_section(w)));
    roff.push_str(&clap_section(|w| man.render_options_section(w)));
    roff.push_str(&clap_section(|w| man.render_subcommands_section(w)));
    roff.push_str(&clap_section(|w| man.render_extra_section(w)));
    roff.push_str(&generators_section());
    roff.push_str(&suites_section());
    Page {
        name: INDEX.to_string(),
        roff,
    }
}

fn generators_section() -> String {
    let mut roff = Roff::new();
    roff.control("SH", ["GENERATORS"]).control("SS", ["elixir"]);
    for &generator in be::GENERATOR_ORDER {
        let about = match be::blueprint_for(generator) {
            Some(blueprint) => blueprint.description().unwrap_or("no description yet"),
            None => "not ported to this workspace yet",
        };
        roff.control("TP", NO_ARGS);
        roff.text([bold(generator)]);
        roff.text([roman(about)]);
        roff.control("br", NO_ARGS);
        roff.text([roman(format!("mix sp.gen.{generator} <element> [options]"))]);
    }
    roff.control("SS", ["typescript"]);
    for (artifact, _) in fe::artifacts() {
        roff.control("TP", NO_ARGS);
        roff.text([bold(artifact)]);
        roff.text([roman(fe::shortdoc(artifact))]);
        roff.control("br", NO_ARGS);
        roff.text([roman(format!("pnpm spgen {artifact} <read-model>"))]);
    }
    roff.to_roff()
}

fn suites_section() -> String {
    let mut roff = Roff::new();
    roff.control("SH", ["SUITES"]).control("SS", ["elixir"]);
    for suite in BE_SUITES {
        roff.control("TP", NO_ARGS);
        roff.text([bold(format!("mix sp.gen.{}", suite.as_str()))]);
        roff.text([roman(suite.members().join(", "))]);
    }
    roff.control("SS", ["typescript"]);
    for (group, members) in fe::suites() {
        roff.control("TP", NO_ARGS);
        roff.text([bold(format!("pnpm spgen {group}"))]);
        roff.text([roman(members.join(", "))]);
    }
    roff.control("TP", NO_ARGS);
    roff.text([bold(format!("pnpm spgen {}", fe::FEATURE))]);
    roff.text([roman(
        fe::artifacts()
            .iter()
            .map(|(artifact, _)| *artifact)
            .collect::<Vec<_>>()
            .join(", "),
    )]);
    roff.to_roff()
}

#[derive(Default)]
enum ListKind {
    #[default]
    Unordered,
    Ordered(u64),
}

#[derive(Default)]
struct Walk {
    roff: Roff,
    text: String,
    cells: Vec<String>,
    list: Option<ListKind>,
    link: String,
    in_item: bool,
    marked: bool,
    in_code: bool,
    skipping: bool,
    title_done: bool,
    needs_break: bool,
}

impl Walk {
    fn run(markdown: &str) -> String {
        let mut walk = Walk::default();
        let options = Options::ENABLE_YAML_STYLE_METADATA_BLOCKS | Options::ENABLE_TABLES;
        for event in Parser::new_ext(markdown, options) {
            walk.event(event);
        }
        walk.roff.to_roff()
    }

    fn event(&mut self, event: Event<'_>) {
        match event {
            Event::Start(tag) => self.start(tag),
            Event::End(tag) => self.end(tag),
            Event::Text(part) | Event::Code(part) | Event::InlineHtml(part) | Event::Html(part) => {
                self.push(&part)
            }
            Event::FootnoteReference(part) => self.push(&part),
            Event::SoftBreak => self.push(if self.in_code { "\n" } else { " " }),
            Event::HardBreak => self.push("\n"),
            Event::Rule
            | Event::TaskListMarker(_)
            | Event::InlineMath(_)
            | Event::DisplayMath(_) => {}
        }
    }

    fn push(&mut self, part: &str) {
        if !self.skipping {
            self.text.push_str(part);
        }
    }

    fn taken(&mut self) -> String {
        std::mem::take(&mut self.text).trim().to_string()
    }

    fn start(&mut self, tag: Tag<'_>) {
        match tag {
            Tag::CodeBlock(_) => {
                if self.in_item {
                    self.item_body();
                }
                self.in_code = true;
            }
            Tag::List(start) => {
                self.list = Some(match start {
                    None => ListKind::Unordered,
                    Some(first) => ListKind::Ordered(first),
                });
            }
            Tag::Item => {
                self.in_item = true;
                self.marked = false;
            }
            Tag::Link { dest_url, .. } => self.link = dest_url.to_string(),
            Tag::Table(_) | Tag::TableHead | Tag::TableRow => self.cells.clear(),
            Tag::MetadataBlock(_) | Tag::HtmlBlock => self.skipping = true,
            _ => {}
        }
    }

    fn end(&mut self, tag: TagEnd) {
        match tag {
            TagEnd::Heading(level) => self.head(level),
            TagEnd::Paragraph => self.paragraph(),
            TagEnd::CodeBlock => self.code_block(),
            TagEnd::List(_) => self.list = None,
            TagEnd::Item => {
                self.item_body();
                self.flush_marker();
                self.in_item = false;
            }
            TagEnd::Link => self.link(),
            TagEnd::TableCell => {
                let cell = self.taken();
                self.cells.push(cell);
            }
            TagEnd::TableRow => self.table_row(),
            TagEnd::TableHead => self.table_head(),
            TagEnd::MetadataBlock(_) | TagEnd::HtmlBlock => self.skipping = false,
            _ => {}
        }
    }

    fn head(&mut self, level: HeadingLevel) {
        let text = self.taken();
        if level == HeadingLevel::H1 && !self.title_done {
            self.title_done = true;
            return;
        }
        let control = match level {
            HeadingLevel::H1 | HeadingLevel::H2 => "SH",
            _ => "SS",
        };
        self.roff.control(control, [text.as_str()]);
        self.needs_break = false;
    }

    fn flush_marker(&mut self) {
        if !self.in_item || self.marked {
            return;
        }
        self.marked = true;
        let marker = match self.list.as_mut() {
            Some(ListKind::Ordered(count)) => {
                *count += 1;
                format!("{}.", *count - 1)
            }
            _ => BULLET.to_string(),
        };
        self.roff.control("IP", [marker.as_str(), "2"]);
        self.needs_break = false;
    }

    fn item_body(&mut self) {
        let text = self.taken();
        if text.is_empty() {
            return;
        }
        self.flush_marker();
        self.roff.text([roman(text)]);
        self.needs_break = true;
    }

    fn paragraph(&mut self) {
        let text = self.taken();
        if text.is_empty() {
            return;
        }
        self.flush_marker();
        if !self.in_item && self.needs_break {
            self.roff.control("PP", NO_ARGS);
        }
        self.roff.text([roman(text)]);
        self.needs_break = true;
    }

    fn code_block(&mut self) {
        self.in_code = false;
        let text = self.taken();
        self.flush_marker();
        self.roff.control("nf", NO_ARGS);
        if !text.is_empty() {
            self.roff.text([roman(text)]);
        }
        self.roff.control("fi", NO_ARGS);
        self.needs_break = true;
    }

    fn link(&mut self) {
        let destination = std::mem::take(&mut self.link);
        let obvious = destination.is_empty()
            || destination.starts_with('#')
            || self.text.ends_with(&destination)
            || self.text.contains(&format!("<{destination}>"));
        if !obvious {
            self.push(&format!(" ({destination})"));
        }
    }

    fn table_head(&mut self) {
        let cells = std::mem::take(&mut self.cells);
        if cells.is_empty() {
            return;
        }
        self.flush_marker();
        if self.needs_break {
            self.roff.control("PP", NO_ARGS);
        }
        self.roff.text([italic(cells.join(", "))]);
        self.needs_break = true;
    }

    fn table_row(&mut self) {
        let cells = std::mem::take(&mut self.cells);
        let Some(first) = cells.first() else {
            return;
        };
        self.roff.control("TP", NO_ARGS);
        self.roff.text([bold(first.clone())]);
        for cell in &cells[1..] {
            self.roff.control("br", NO_ARGS);
            self.roff.text([roman(cell.clone())]);
        }
        self.needs_break = true;
    }
}

fn markdown_to_roff(markdown: &str) -> String {
    Walk::run(markdown)
}

#[cfg(test)]
mod tests {
    use super::*;

    const DOC: &str = "---\ngenerator: \"mix sp.gen.demo <element>\"\n---\n\n# Demo\n\nThe demo reads the model.\n\n## Left to you\n\n- First thing to do.\n- Second thing.\n\n```sh\nmix sp.gen.demo widget\n```\n\n### Fine point\n\n| Shape | Work |\n| --- | --- |\n| collection | the whole list |\n";

    fn unescaped(roff: &str) -> String {
        roff.replace(r"\-", "-")
            .replace(r"\fI", "")
            .replace(r"\fR", "")
    }

    #[test]
    fn walker_renders_headings_lists_and_code() {
        let roff = markdown_to_roff(DOC);
        assert!(!roff.contains("Demo"), "the title becomes NAME:\n{roff}");
        assert!(
            !roff.contains("generator:"),
            "front matter is not prose:\n{roff}"
        );
        assert!(roff.contains(".SH \"Left to you\""), "{roff}");
        assert!(roff.contains(".SS \"Fine point\""), "{roff}");
        assert!(roff.contains(r".IP \[bu] 2"), "{roff}");
        assert!(roff.contains("First thing to do."), "{roff}");
        assert!(
            roff.contains(".nf\nmix sp.gen.demo widget\n.fi\n"),
            "{roff}"
        );
        assert!(roff.contains("The demo reads the model."), "{roff}");
        assert!(roff.contains(".TP\n\\fBcollection\\fR"), "{roff}");
        assert!(roff.contains("the whole list"), "{roff}");
        assert!(roff.contains("\\fIShape, Work\\fR"), "{roff}");
    }

    #[test]
    fn be_page_carries_kinds_template_and_binding() {
        let roff = unescaped(&page("command", None).expect("command is a generator"));
        assert!(
            roff.starts_with(".TH \"SPARCH-COMMAND\" \"1\" \"\" \"sparch "),
            "{roff}"
        );
        assert!(roff.contains(".SH NAME"), "{roff}");
        assert!(
            roff.contains("mix sp.gen.command [options] <COMMAND>"),
            "the synopsis is the binding call:\n{roff}"
        );
        assert!(!roff.contains("Typing it"), "{roff}");
        assert!(
            roff.contains("Generates a command module, its test and router registration"),
            "{roff}"
        );
        assert!(roff.contains(".SH OPTIONS"), "{roff}");
        assert!(roff.contains("--template"), "{roff}");
        assert!(
            roff.contains("what the operation does: create|update|delete|none"),
            "{roff}"
        );
        assert!(roff.contains(".SH \"SEE ALSO\""), "{roff}");
        assert!(roff.contains("suites: operation, feature"), "{roff}");
    }

    #[test]
    fn be_fixed_page_takes_no_template_and_keeps_its_doc() {
        let roff = unescaped(&page("read_model", None).expect("read_model is a generator"));
        assert!(roff.starts_with(".TH \"SPARCH-READ_MODEL\""), "{roff}");
        assert!(roff.contains("<READ-MODEL>"), "{roff}");
        assert!(!roff.contains("--template"), "{roff}");
        assert!(
            roff.contains("The queryable projection of the events"),
            "the blueprint doc is the description:\n{roff}"
        );
    }

    #[test]
    fn projector_page_lists_its_module_path_template() {
        let roff = unescaped(&page("projector", Some("elixir")).expect("projector is a generator"));
        assert!(roff.contains(".SS \"Generated files\""), "{roff}");
        assert!(
            roff.contains(
                "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/projector.ex (projection clause per event)"
            ),
            "{roff}"
        );
    }

    #[test]
    fn every_generator_page_lists_generated_files() {
        for generator in be::GENERATOR_ORDER {
            let roff = page(generator, Some("elixir")).expect("be generator page");
            assert!(
                roff.contains(".SS \"Generated files\"\n.IP \\[bu] 2\n"),
                "{generator} must list the files it writes"
            );
        }
        for (artifact, _) in fe::artifacts() {
            let roff = page(artifact, Some("typescript")).expect("fe artifact page");
            assert!(
                roff.contains(".SS \"Generated files\"\n.IP \\[bu] 2\n"),
                "{artifact} must list the files it writes"
            );
        }
    }

    #[test]
    fn fe_page_is_built_from_the_shortdoc() {
        let roff = unescaped(&page("domain-object", None).expect("domain-object is an artifact"));
        assert!(roff.starts_with(".TH \"SPARCH-DOMAIN-OBJECT\""), "{roff}");
        assert!(
            roff.contains("pnpm spgen domain-object <read-model>"),
            "{roff}"
        );
        assert!(
            roff.contains("Generates the domain object interface and its fields type"),
            "{roff}"
        );
        assert!(roff.contains("<READ-MODEL>"), "{roff}");
        assert!(roff.contains("suites: domain-objects, feature"), "{roff}");
        assert!(roff.contains(".SH OPTIONS"), "{roff}");
        assert!(!roff.contains("Typing it"), "{roff}");
        assert!(roff.contains(".SS \"Generated files\""), "{roff}");
    }

    #[test]
    fn schema_answers_both_languages_and_names_the_typescript_page() {
        assert_eq!(
            page_name("schema", Some("elixir")).expect("be schema"),
            "sparch-schema"
        );
        assert_eq!(
            page_name("schema", Some("typescript")).expect("fe schema"),
            "sparch-schema-typescript"
        );
        let elixir = unescaped(&page("schema", Some("elixir")).expect("be page"));
        let typescript = unescaped(&page("schema", Some("typescript")).expect("typescript page"));
        assert!(elixir.contains("mix sp.gen.schema [options]"), "{elixir}");
        assert!(
            typescript.contains("pnpm spgen schema <read-model>"),
            "{typescript}"
        );
        assert!(
            !typescript.contains("OpenApiSpex"),
            "the BE doc is not the FE page:\n{typescript}"
        );
        let error = page_name("schema", None).expect_err("ambiguous");
        assert!(error.contains("both languages"), "{error}");
    }

    #[test]
    fn index_lists_every_generator_and_suite() {
        let roff = unescaped(&page(INDEX, None).expect("the index exists"));
        assert!(roff.starts_with(".TH \"SPARCH\" \"1\""), "{roff}");
        assert!(roff.contains(".SH GENERATORS"), "{roff}");
        assert!(roff.contains(".SS elixir"), "{roff}");
        assert!(roff.contains("read_model"), "{roff}");
        assert!(roff.contains("Generates the shared read model"), "{roff}");
        assert!(roff.contains("mix sp.gen.read_model <element>"), "{roff}");
        assert!(roff.contains(".SH SUITES"), "{roff}");
        assert!(roff.contains("mix sp.gen.operation"), "{roff}");
        assert!(roff.contains("pnpm spgen domain-objects"), "{roff}");
        assert!(roff.contains("blueprints render units"), "{roff}");
    }

    #[test]
    fn pages_cover_every_generator_once() {
        let pages = pages();
        assert_eq!(
            pages.len(),
            be::GENERATOR_ORDER.len() + fe::artifacts().len() + 1
        );
        let mut names: Vec<&str> = pages.iter().map(|page| page.name.as_str()).collect();
        names.sort_unstable();
        names.dedup();
        assert_eq!(names.len(), pages.len(), "page names are unique");
        for page in &pages {
            assert!(page.roff.starts_with(".TH"), "{}", page.name);
            assert!(page.roff.ends_with('\n'), "{}", page.name);
            if page.name != INDEX {
                assert!(
                    page.roff.contains(".SH \"SEE ALSO\"\nsparch(1)\n"),
                    "{} must point at the index",
                    page.name
                );
            }
        }
    }

    #[test]
    fn suites_get_no_page() {
        let error = page_name("operation", None).expect_err("suites get no page");
        assert!(error.contains("no page for 'operation'"), "{error}");
    }
}
