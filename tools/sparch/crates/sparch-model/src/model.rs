//! Model loader and index.

use std::{
    fs,
    path::{Path, PathBuf},
};

use crate::element::{Element, ElementKind, build_address, scope_chain};

#[derive(Clone)]
pub struct Model {
    pub root: PathBuf,
    pub elements: Vec<Element>,
}

#[derive(Debug, PartialEq)]
pub enum ResolveError {
    /// The name is ambiguous — carry the full `esdm:` references.
    Ambiguous(Vec<String>),
    Unknown(String),
    /// The name exists, but only in kinds the caller cannot use.
    KindMismatch {
        name: String,
        found: Vec<String>,
    },
    Invalid(String),
}

impl std::fmt::Display for ResolveError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Ambiguous(addresses) => {
                write!(
                    f,
                    "the name is ambiguous, use one of these esdm: references:\n{}",
                    addresses
                        .iter()
                        .map(|a| format!("  {a}"))
                        .collect::<Vec<_>>()
                        .join("\n")
                )
            }
            Self::Unknown(name) => write!(f, "no such element: {name}"),
            Self::KindMismatch { name, found } => write!(
                f,
                "no element of the accepted kinds named \"{name}\" — the name exists as:\n{}",
                found
                    .iter()
                    .map(|a| format!("  {a}"))
                    .collect::<Vec<_>>()
                    .join("\n")
            ),
            Self::Invalid(detail) => write!(f, "invalid address: {detail}"),
        }
    }
}

impl Model {
    /// Load every `*.esdm.yaml` document under `root` (multi-document files
    /// included). Files that fail to read parse contribute nothing — the
    /// resolution then reports the element as unknown, mirroring the BE's
    /// forgiving load with loud resolve.
    pub fn load(root: &Path) -> Self {
        let mut files = Vec::new();
        collect_yaml(root, &mut files);
        files.sort();

        let elements = files
            .iter()
            .flat_map(|path| load_file(path))
            .collect::<Vec<_>>();

        Model {
            root: root.to_path_buf(),
            elements,
        }
    }

    /// Resolve an address into exactly one element. Bare names are narrowed
    /// to `kinds` before the unique/ambiguous decision; explicit forms keep
    /// addressing what they name.
    pub fn resolve(&self, address: &str, kinds: &[ElementKind]) -> Result<Element, ResolveError> {
        if let Some(body) = address.strip_prefix("esdm:") {
            return self.resolve_reference(body);
        }
        if address.ends_with(".esdm.yaml") {
            return self.resolve_file(address);
        }
        if let Some((kind, name)) = address.split_once('.') {
            return self.resolve_kind_name(kind, name);
        }
        self.resolve_name(address, kinds)
    }

    pub fn find(&self, kind: ElementKind, name: &str) -> Option<Element> {
        self.elements
            .iter()
            .find(|e| e.kind == kind && e.name == name)
            .cloned()
    }

    /// All events owned by an aggregate, sorted by name.
    pub fn events_of(&self, aggregate: &str) -> Vec<Element> {
        let mut events: Vec<Element> = self
            .elements
            .iter()
            .filter(|e| e.kind == ElementKind::Event && e.aggregate_name() == Some(aggregate))
            .cloned()
            .collect();
        events.sort_by(|a, b| a.name.cmp(&b.name));
        events
    }

    /// Commands bound to an aggregate, sorted by name.
    pub fn commands_of(&self, aggregate: &str) -> Vec<Element> {
        let mut commands: Vec<Element> = self
            .elements
            .iter()
            .filter(|e| e.kind == ElementKind::Command && e.aggregate_name() == Some(aggregate))
            .cloned()
            .collect();
        commands.sort_by(|a, b| a.name.cmp(&b.name));
        commands
    }

    /// Queries reading a read model, sorted by name.
    pub fn queries_of(&self, read_model: &str) -> Vec<Element> {
        let mut queries: Vec<Element> = self
            .elements
            .iter()
            .filter(|e| e.kind == ElementKind::Query && e.read_model_name() == Some(read_model))
            .cloned()
            .collect();
        queries.sort_by(|a, b| a.name.cmp(&b.name));
        queries
    }

    /// The read model for an element.
    pub fn read_model_for(&self, element: &Element) -> Option<Element> {
        match element.kind {
            ElementKind::Query => element
                .read_model_name()
                .and_then(|rm| self.find(ElementKind::ReadModel, rm)),
            _ => {
                let name = element.aggregate_name().unwrap_or(&element.name);
                self.find(ElementKind::ReadModel, name)
            }
        }
    }

    fn resolve_reference(&self, body: &str) -> Result<Element, ResolveError> {
        let segments: Vec<(String, String)> = body
            .split('/')
            .filter(|s| !s.is_empty())
            .map(|s| {
                s.split_once('=')
                    .map(|(k, n)| (k.to_string(), n.to_string()))
            })
            .collect::<Option<Vec<_>>>()
            .ok_or_else(|| ResolveError::Invalid(body.to_string()))?;

        if segments.is_empty() {
            return Err(ResolveError::Invalid(body.to_string()));
        }

        let (target_kind, target_name) = segments.last().unwrap();
        let ancestors = &segments[..segments.len() - 1];

        let matches: Vec<&Element> = self
            .elements
            .iter()
            .filter(|e| {
                e.scope
                    .iter()
                    .zip(ancestors)
                    .all(|((k, n), (ak, an))| k == ak && n == an)
                    && e.scope.len() == ancestors.len()
                    && format!("{}={}", ElementKind::as_str(&e.kind), e.name)
                        == format!("{target_kind}={target_name}")
            })
            .collect();

        match matches.as_slice() {
            [element] => Ok((*element).clone()),
            [] => Err(ResolveError::Unknown(format!("esdm:{body}"))),
            many => Err(ResolveError::Ambiguous(
                many.iter().map(|e| e.address.clone()).collect(),
            )),
        }
    }

    fn resolve_file(&self, path: &str) -> Result<Element, ResolveError> {
        let wanted: Vec<String> = path
            .trim_start_matches("./")
            .split('/')
            .filter(|s| !s.is_empty())
            .map(str::to_string)
            .collect();

        let matches: Vec<&Element> = self
            .elements
            .iter()
            .filter(|e| {
                let parts: Vec<String> = e
                    .source
                    .to_string_lossy()
                    .split('/')
                    .filter(|s| !s.is_empty())
                    .map(str::to_string)
                    .collect();
                suffix_match(&parts, &wanted)
            })
            .collect();

        match matches.as_slice() {
            [element] => Ok((*element).clone()),
            [] => Err(ResolveError::Invalid(format!(
                "not an element of the model: {path}"
            ))),
            many => Err(ResolveError::Ambiguous(
                many.iter().map(|e| e.address.clone()).collect(),
            )),
        }
    }

    fn resolve_kind_name(&self, kind: &str, name: &str) -> Result<Element, ResolveError> {
        let matches: Vec<&Element> = self
            .elements
            .iter()
            .filter(|e| ElementKind::as_str(&e.kind) == kind && e.name == name)
            .collect();
        match matches.as_slice() {
            [element] => Ok((*element).clone()),
            [] => Err(ResolveError::Unknown(format!("{kind}.{name}"))),
            many => Err(ResolveError::Ambiguous(
                many.iter().map(|e| e.address.clone()).collect(),
            )),
        }
    }

    fn resolve_name(&self, name: &str, kinds: &[ElementKind]) -> Result<Element, ResolveError> {
        let matching: Vec<&Element> = self.elements.iter().filter(|e| e.name == name).collect();
        let narrowed: Vec<&Element> = if kinds.is_empty() {
            matching.clone()
        } else {
            matching
                .iter()
                .cloned()
                .filter(|e| kinds.contains(&e.kind))
                .collect()
        };

        match narrowed.as_slice() {
            [element] => Ok((*element).clone()),
            [] => {
                if !matching.is_empty() && !kinds.is_empty() {
                    Err(ResolveError::KindMismatch {
                        name: name.to_string(),
                        found: matching.iter().map(|e| e.address.clone()).collect(),
                    })
                } else {
                    Err(ResolveError::Unknown(name.to_string()))
                }
            }
            many => Err(ResolveError::Ambiguous(
                many.iter().map(|e| e.address.clone()).collect(),
            )),
        }
    }
}

/// One path is a segment-suffix of the other (absolute, repo-relative,
/// cwd-relative).
fn suffix_match(longer: &[String], shorter: &[String]) -> bool {
    let (longer, shorter) = if longer.len() >= shorter.len() {
        (longer, shorter)
    } else {
        (shorter, longer)
    };
    longer[longer.len() - shorter.len()..] == shorter[..]
}

fn collect_yaml(dir: &Path, files: &mut Vec<PathBuf>) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };
    for entry in entries.filter_map(Result::ok) {
        let path = entry.path();
        if path.is_dir() {
            collect_yaml(&path, files);
        } else if path
            .file_name()
            .is_some_and(|name| name.to_string_lossy().ends_with(".esdm.yaml"))
        {
            files.push(path);
        }
    }
}

fn load_file(path: &Path) -> Vec<Element> {
    let Ok(text) = fs::read_to_string(path) else {
        return vec![];
    };
    documents(&text)
        .filter_map(|doc| to_element(doc, path))
        .collect()
}

/// Split a multi-document YAML stream on the ESDM document separator.
fn documents(text: &str) -> impl Iterator<Item = serde_yaml::Value> {
    let chunks: Vec<&str> = text
        .split("\n---")
        .map(|chunk| chunk.trim_start_matches(['-', '\n', '\r']))
        .collect();
    chunks
        .into_iter()
        .filter(|chunk| !chunk.trim().is_empty())
        .filter_map(|chunk| serde_yaml::from_str(chunk).ok())
}

fn to_element(doc: serde_yaml::Value, path: &Path) -> Option<Element> {
    let doc: serde_json::Value = serde_json::to_value(doc).ok()?;
    let kind_text = doc.get("kind")?.as_str()?;
    let name = doc.get("name")?.as_str()?.to_string();
    let scope = scope_chain(&doc);
    let address = build_address(&scope, kind_text, &name);
    Some(Element {
        kind: ElementKind::parse(kind_text),
        name,
        scope,
        doc,
        source: path.to_path_buf(),
        address,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn corpus() -> Model {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        Model::load(&root.canonicalize().expect("shared fixture corpus"))
    }

    #[test]
    fn loads_the_shared_fixture_corpus() {
        let model = corpus();
        assert!(
            model
                .elements
                .iter()
                .any(|e| e.kind == ElementKind::ReadModel && e.name == "widget"),
            "fixture corpus should hold the widget read model"
        );
    }

    #[test]
    fn bare_name_narrows_by_kind() {
        let model = corpus();
        // `widget` names a read model and an aggregate — kinds decide.
        let by_read_model = model.resolve("widget", &[ElementKind::ReadModel]);
        assert!(matches!(by_read_model, Ok(e) if e.kind == ElementKind::ReadModel));
        let ambiguous = model.resolve("widget", &[]);
        assert!(matches!(ambiguous, Err(ResolveError::Ambiguous(_))));
    }

    #[test]
    fn kind_name_address_resolves() {
        let model = corpus();
        let command = model
            .resolve("command.create-widget", &[])
            .expect("command.create-widget");
        assert_eq!(command.kind, ElementKind::Command);
        assert_eq!(command.aggregate_name(), Some("widget"));
    }
}
