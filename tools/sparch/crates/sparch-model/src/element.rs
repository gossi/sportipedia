use std::path::PathBuf;

use serde_json::Value;

/// ESDM element kinds this tool knows about. Unknown kinds load as
/// `Other` — the model may carry elements the FE blueprints ignore.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ElementKind {
    Domain,
    Subdomain,
    BoundedContext,
    Aggregate,
    Command,
    Event,
    EventHandler,
    Policy,
    ProcessManager,
    ReadModel,
    Query,
    Entity,
    ValueObject,
    DomainService,
    Actor,
    ExternalSystem,
    ContextMapping,
    DynamicConsistencyBoundary,
    Feature,
    Other,
}

impl ElementKind {
    pub fn parse(s: &str) -> Self {
        match s {
            "domain" => Self::Domain,
            "subdomain" => Self::Subdomain,
            "bounded-context" => Self::BoundedContext,
            "aggregate" => Self::Aggregate,
            "command" => Self::Command,
            "event" => Self::Event,
            "event-handler" => Self::EventHandler,
            "policy" => Self::Policy,
            "process-manager" => Self::ProcessManager,
            "read-model" => Self::ReadModel,
            "query" => Self::Query,
            "entity" => Self::Entity,
            "value-object" => Self::ValueObject,
            "domain-service" => Self::DomainService,
            "actor" => Self::Actor,
            "external-system" => Self::ExternalSystem,
            "context-mapping" => Self::ContextMapping,
            "dynamic-consistency-boundary" => Self::DynamicConsistencyBoundary,
            "feature" => Self::Feature,
            _ => Self::Other,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Domain => "domain",
            Self::Subdomain => "subdomain",
            Self::BoundedContext => "bounded-context",
            Self::Aggregate => "aggregate",
            Self::Command => "command",
            Self::Event => "event",
            Self::EventHandler => "event-handler",
            Self::Policy => "policy",
            Self::ProcessManager => "process-manager",
            Self::ReadModel => "read-model",
            Self::Query => "query",
            Self::Entity => "entity",
            Self::ValueObject => "value-object",
            Self::DomainService => "domain-service",
            Self::Actor => "actor",
            Self::ExternalSystem => "external-system",
            Self::ContextMapping => "context-mapping",
            Self::DynamicConsistencyBoundary => "dynamic-consistency-boundary",
            Self::Feature => "feature",
            Self::Other => "other",
        }
    }
}

/// One ESDM model element.
#[derive(Clone, Debug)]
pub struct Element {
    pub kind: ElementKind,
    pub name: String,
    /// The scope chain as `{kind, name}` pairs, the document head serialized.
    pub scope: Vec<(String, String)>,
    pub doc: Value,
    pub source: PathBuf,
    pub address: String,
}

impl Element {
    pub fn aggregate_name(&self) -> Option<&str> {
        self.scope
            .iter()
            .find(|(kind, _)| kind == "aggregate")
            .map(|(_, name)| name.as_str())
    }

    pub fn read_model_name(&self) -> Option<&str> {
        self.doc.get("readModel").and_then(Value::as_str)
    }

    pub fn segment(&self) -> String {
        format!("{}={}", ElementKind::as_str(&self.kind), self.name)
    }

    pub fn description(&self) -> Option<&str> {
        self.doc.get("description").and_then(Value::as_str)
    }

    pub fn actors(&self) -> Vec<String> {
        self.doc
            .get("actors")
            .and_then(Value::as_array)
            .map(|items| {
                items
                    .iter()
                    .filter_map(Value::as_str)
                    .map(str::to_string)
                    .collect()
            })
            .unwrap_or_default()
    }

    pub fn publishes(&self) -> Vec<String> {
        self.doc
            .get("publishes")
            .and_then(Value::as_array)
            .map(|items| {
                items
                    .iter()
                    .filter_map(Value::as_str)
                    .map(str::to_string)
                    .collect()
            })
            .unwrap_or_default()
    }

    pub fn invariants(&self) -> Vec<Value> {
        named_entries(self.doc.get("invariants"))
    }

    pub fn constraints(&self) -> Vec<Value> {
        named_entries(self.doc.get("constraints"))
    }
}

fn named_entries(value: Option<&Value>) -> Vec<Value> {
    value.and_then(Value::as_array).cloned().unwrap_or_default()
}

/// The `esdm:` address for a scope chain plus the element's own segment.
pub fn build_address(scope: &[(String, String)], kind: &str, name: &str) -> String {
    let mut segments: Vec<String> = scope.iter().map(|(k, n)| format!("{k}={n}")).collect();
    segments.push(format!("{kind}={name}"));
    format!("esdm:{}", segments.join("/"))
}

/// The scope chain of a document: scope fields written as the kinds they
/// name; a domain or context-mapping carries no scope; a domain document
/// self-scopes.
pub fn scope_chain(doc: &Value) -> Vec<(String, String)> {
    let mut chain = Vec::new();
    let kind = doc.get("kind").and_then(Value::as_str).unwrap_or_default();
    let scope = doc.get("scope").cloned().unwrap_or(Value::Null);

    for (field, scope_kind) in [
        ("domain", "domain"),
        ("boundedContext", "bounded-context"),
        ("aggregate", "aggregate"),
        ("dynamicConsistencyBoundary", "dynamic-consistency-boundary"),
    ] {
        if let Some(name) = scope.get(field).and_then(Value::as_str) {
            chain.push((scope_kind.to_string(), name.to_string()));
        }
    }

    if chain.is_empty() {
        if kind == "domain" || kind == "context-mapping" {
            return vec![];
        }
        if let Some(name) = doc.get("name").and_then(Value::as_str) {
            chain.push(("domain".to_string(), name.to_string()));
        }
    }
    chain
}
