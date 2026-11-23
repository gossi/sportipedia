//! The run context for the BE blueprints.
//!
//! Everything a blueprint reads is pre-resolved here: identity, location
//! (inferred, overridable, hard error when unknown), the derived operation,
//! the canonical fields with the injected `id`, the invariant resolution
//! (`validators` / `unresolved`), and the placeholder rendering entry
//! points.

use std::path::PathBuf;

use sparch_model::fields::Field;
use sparch_model::invariants::{Validator, ValidatorKind};
use sparch_model::placeholders::{self, Slots, Vars};
use sparch_model::{Element, ElementKind, Model};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Operation {
    Create,
    Update,
    Delete,
    None,
    Read,
    Collection,
}

impl Operation {
    pub fn parse(word: &str) -> Option<Operation> {
        match word {
            "create" => Some(Operation::Create),
            "update" => Some(Operation::Update),
            "delete" => Some(Operation::Delete),
            "none" => Some(Operation::None),
            "read" => Some(Operation::Read),
            "collection" => Some(Operation::Collection),
            _ => None,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Operation::Create => "create",
            Operation::Update => "update",
            Operation::Delete => "delete",
            Operation::None => "none",
            Operation::Read => "read",
            Operation::Collection => "collection",
        }
    }
}

/// How a collection query paginates — the model's page style.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PageStyle {
    Numbered,
    Offset,
    None,
}

impl PageStyle {
    pub fn as_str(&self) -> &'static str {
        match self {
            PageStyle::Numbered => "numbered",
            PageStyle::Offset => "offset",
            PageStyle::None => "none",
        }
    }
}

#[derive(Debug)]
pub enum ContextError {
    /// Neither inferred nor provided — the run tells the operator which
    /// flag fixes it.
    UnknownLocation(&'static str),
}

impl std::fmt::Display for ContextError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ContextError::UnknownLocation(var) => write!(f, "unknown location: {var}"),
        }
    }
}

#[allow(dead_code)]
/// A model field as the BE sees it: the canonical `sparch_model` field plus
/// the `internal` flag the create flow carries (the id is dispatched, not
/// provided by the caller) and the relation keyword, which is what tells
/// the schema blueprint to write an association instead of a plain field.
#[derive(Clone)]
pub struct Befield {
    pub name: String,
    pub ty: String,
    pub format: Option<String>,
    pub description: Option<String>,
    pub required: bool,
    pub internal: bool,
    pub relation: Option<sparch_model::Relation>,
}

impl Befield {
    pub(crate) fn from_field(f: &Field) -> Self {
        Befield {
            name: f.name.clone(),
            ty: f.ty.clone(),
            format: f.format.clone(),
            description: f.description.clone(),
            required: f.required,
            internal: false,
            relation: f.relation.clone(),
        }
    }

    /// Whether this field's relation carries the parent side of an edge:
    /// no database field, never cast, rendered as an association macro.
    pub fn is_virtual(&self) -> bool {
        self.relation.as_ref().is_some_and(|r| r.kind.is_virtual())
    }

    /// The database field a changeset consumes for this column: the
    /// relation's column on the id-carrying kind, the name otherwise.
    pub fn column(&self) -> String {
        match &self.relation {
            Some(relation) if relation.kind.carries_column() => {
                sparch_model::column_of(&self.name, relation)
            }
            _ => self.name.clone(),
        }
    }
}

#[derive(Clone)]
pub struct Context {
    pub element: Element,
    pub model: Model,
    pub subdomain: String,
    pub composite: String,
    pub constituent: String,
    pub operation: Option<Operation>,
    pub aggregate: Option<Element>,
    pub read_model: Option<Element>,
    pub fields: Vec<Befield>,
    pub validators: Vec<Validator>,
    /// Rules the model states that no pattern realizes, `(name, rule)`.
    pub unresolved: Vec<(String, String)>,
    /// The events the element publishes, in the model's `publishes` order. A
    /// published name the model holds no event for is dropped.
    pub events: Vec<Element>,
    /// The feature scenarios that exercise this element.
    pub scenarios: Vec<serde_json::Value>,
    /// The actors the model names for this element.
    pub actors: Vec<String>,
    pub repo_root: PathBuf,
}

/// Build options — the CLI overrides and the selected operation.
#[derive(Default)]
pub struct ContextOptions {
    pub operation: Option<Operation>,
    pub subdomain: Option<String>,
    pub composite: Option<String>,
    pub constituent: Option<String>,
    pub repo_root: PathBuf,
}

impl Context {
    pub fn build(
        model: &Model,
        element: &Element,
        opts: &ContextOptions,
    ) -> Result<Context, ContextError> {
        let subdomain = opts
            .subdomain
            .clone()
            .or_else(|| infer_location(element).first.map(|s| s.to_string()))
            .ok_or(ContextError::UnknownLocation("subdomain"))?;
        let composite = opts
            .composite
            .clone()
            .or_else(|| infer_location(element).second.map(|s| s.to_string()))
            .ok_or(ContextError::UnknownLocation("composite"))?;
        let constituent = opts.constituent.clone().or_else(|| {
            let (_, _, c) = infer_constituent(model, element);
            c
        });
        let constituent = constituent.ok_or(ContextError::UnknownLocation("constituent"))?;

        let aggregate = aggregate_link(model, element);
        let read_model = read_model_link(model, element);

        let operation = match opts.operation {
            Some(op) => Some(op),
            None => derive_operation(model, element),
        };

        let fields = fields_for(element, operation.as_ref(), aggregate.as_ref());
        let (validators, unresolved) =
            validators_for(model, element, aggregate.as_ref(), &fields, &constituent);

        Ok(Context {
            element: element.clone(),
            model: model.clone(),
            subdomain,
            composite,
            constituent,
            operation,
            aggregate,
            read_model,
            fields,
            validators,
            unresolved,
            events: published_events(model, element),
            scenarios: scenarios(model, element),
            actors: element.actors(),
            repo_root: opts.repo_root.clone(),
        })
    }

    // ------------------------------------------------------------- derived

    /// The same context driven from a related element. Only the element is
    /// replaced; every derived fact (fields, validators, location, links)
    /// keeps the original's, so rendering re-resolves the identity
    /// placeholders from the new element.
    pub fn with_element(&self, element: &Element) -> Context {
        let mut ctx = self.clone();
        ctx.element = element.clone();
        ctx
    }

    /// All events owned by the context's aggregate, sorted by name.
    pub fn aggregate_events(&self) -> Vec<Element> {
        if let Some(aggregate) = &self.aggregate {
            return self.model.events_of(&aggregate.name);
        }
        match self.element.aggregate_name() {
            Some(name) => self.model.events_of(name),
            None => Vec::new(),
        }
    }

    /// The effect the read model declares for an event: a real operation,
    /// `None` for the declared `none` (not to materialize), or `None` when
    /// nobody has decided. The private `declared_effect` reads `:invalid`
    /// as undecided. Both the
    /// undecided and the invalid answers generate no clause; the gap is
    /// reported by the run.
    pub fn effect_for_event(&self, event_name: &str) -> Option<Operation> {
        let rm = self.read_model.as_ref()?;
        sparch_model::annotations::declared_effects(rm)
            .into_iter()
            .find(|(event, _)| event == event_name)
            .and_then(|(_, effect)| effect)
            .and_then(|word| Operation::parse(&word))
    }

    /// The relation keyword behind a command or event data field: the
    /// read model's `belongs_to` property that the field's name
    /// correlates to (`apparatus_id` writes the edge `apparatus`), with
    /// the database field it lands in. The projector and the controller
    /// translation are the only consumers — the column name must not
    /// escape above them.
    pub fn relation_for_data_field(&self, data_field: &str) -> Option<(Field, String)> {
        let rm = self.read_model.as_ref()?;
        let edge = sparch_model::fields(rm).into_iter().find(|f| {
            f.relation
                .as_ref()
                .is_some_and(|r| r.kind == sparch_model::RelationKind::BelongsTo)
                && sparch_model::field_matches_property(data_field, f)
        })?;
        let column = sparch_model::relation_column(&edge).unwrap_or_else(|| edge.name.clone());
        Some((edge, column))
    }

    /// The command's data fields that write a relation: `(edge property
    /// name, command data field name)` in data-field order — the JSON:API
    /// linkage key together with the command key it flattens into.
    pub fn command_relations(&self) -> Vec<(String, String)> {
        self.fields
            .iter()
            .filter(|f| f.name != "id" && !f.internal)
            .filter_map(|f| {
                let (edge, _) = self.relation_for_data_field(&f.name)?;
                Some((edge.name.clone(), f.name.clone()))
            })
            .collect()
    }

    /// The projector's single translation: event data fields whose
    /// relation stores into a database field that differs from the event
    /// key. `(event field, column)` in field order; a derived column is
    /// the same string as the event key and never appears here. This is
    /// the only place a `column` override is read outside the schema.
    pub fn column_renames(&self) -> Vec<(String, String)> {
        self.fields
            .iter()
            .filter(|f| f.name != "id" && !f.internal)
            .filter_map(|f| {
                let (_, column) = self.relation_for_data_field(&f.name)?;
                (f.name != column).then(|| (f.name.clone(), column))
            })
            .collect()
    }

    /// The context of a related read model: its own location, read from
    /// the model layout, so module and path templates render for the
    /// target rather than for this element. `None` when the name does not
    /// resolve — the integrity checks report that, the blueprint skips it.
    pub fn target_context(&self, read_model_name: &str) -> Option<Context> {
        let element = self.model.find(ElementKind::ReadModel, read_model_name)?;
        Context::build(
            &self.model,
            &element,
            &ContextOptions {
                repo_root: self.repo_root.clone(),
                ..Default::default()
            },
        )
        .ok()
    }

    /// The module Pascal form of a kebab name (PublicAPI, ReadModel, …).
    pub fn pascal(name: &str) -> String {
        name.split('-')
            .map(|part| {
                // Elixir `String.capitalize`: upcase the first character,
                // downcase the rest
                let mut chars = part.chars();
                match chars.next() {
                    None => String::new(),
                    Some(first) => {
                        let rest: String = chars.flat_map(|c| c.to_lowercase()).collect();
                        format!("{}{rest}", first.to_uppercase())
                    }
                }
            })
            .collect()
    }

    /// The snake_case operation key (`catalog_apparatus`).
    pub fn op_snake(&self) -> String {
        self.element.name.replace('-', "_")
    }

    /// True for queries whose operation is a collection read.
    pub fn collection(&self) -> bool {
        self.element.kind == ElementKind::Query && self.operation == Some(Operation::Collection)
    }

    /// Fields carrying a unique rule.
    pub fn unique_fields(&self) -> Vec<String> {
        self.validators
            .iter()
            .filter(|v| v.kind == ValidatorKind::Unique)
            .map(|v| v.field.clone())
            .collect()
    }

    /// Elixir type for a typedstruct field.
    pub fn elixir_type(f: &Befield) -> String {
        match f.ty.as_str() {
            "integer" => "integer()",
            "number" => "float()",
            "boolean" => "boolean()",
            "object" => "map()",
            "array" => "[term()]",
            _ => "String.t()",
        }
        .to_string()
    }

    /// Ecto type atom text for schema fields.
    pub fn ecto_type(f: &Befield) -> String {
        match (f.ty.as_str(), f.format.as_deref()) {
            ("string", Some("uuid")) => ":binary_id".to_string(),
            ("string", Some("date-time")) => ":utc_datetime_usec".to_string(),
            ("string", _) => ":string".to_string(),
            ("integer", _) => ":integer".to_string(),
            ("number", _) => ":float".to_string(),
            ("boolean", _) => ":boolean".to_string(),
            ("object", _) => ":map".to_string(),
            ("array", _) => "{:array, :string}".to_string(),
            _ => ":string".to_string(),
        }
    }

    /// The description prose or `None`.
    pub fn description(&self) -> Option<&str> {
        self.element.description()
    }

    /// The parameter names of a query's `parameters.oneOf` (`["id", "slug"]`).
    /// A model that declares none answers with
    /// the empty list. Key order is the parsed document's, the same reading
    /// every mapping in the model crate uses (YAML mappings lose key order);
    /// this wave's consumer only asks whether the list is empty.
    pub fn one_of_params(&self) -> Vec<String> {
        let branches = self
            .element
            .doc
            .get("parameters")
            .and_then(|p| p.get("oneOf"))
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        let mut names: Vec<String> = Vec::new();
        for branch in &branches {
            if let Some(properties) = branch.get("properties").and_then(|v| v.as_object()) {
                for key in properties.keys() {
                    if !names.contains(key) {
                        names.push(key.clone());
                    }
                }
            }
        }
        names
    }

    /// The path parameter name for a read query (`id`, `id_or_slug`).
    pub fn read_param(&self) -> String {
        let names = self.one_of_params();
        if names.is_empty() {
            return "id".to_string();
        }
        names.join("_or_")
    }

    /// A query's `parameters.properties` (collection queries), as a map or
    /// `None` when the model declares none.
    pub fn query_parameters(&self) -> Option<&serde_json::Map<String, serde_json::Value>> {
        self.element
            .doc
            .get("parameters")
            .and_then(|p| p.get("properties"))
            .and_then(|v| v.as_object())
    }

    /// The fields a collection query may be filtered by — the names its
    /// `parameters.filter.properties` declares, sorted so a regenerated
    /// file is stable.
    pub fn filterable_fields(&self) -> Vec<String> {
        let mut keys: Vec<String> = self
            .query_parameters()
            .and_then(|p| p.get("filter"))
            .and_then(|f| f.get("properties"))
            .and_then(|v| v.as_object())
            .map(|props| props.keys().cloned().collect())
            .unwrap_or_default();
        keys.sort();
        keys
    }

    /// The fields a collection query may be sorted by: the model's
    /// `sort.properties` when it declares them, its filterable fields when
    /// it does not.
    pub fn sortable_fields(&self) -> Vec<String> {
        if self.element.kind != ElementKind::Query {
            return Vec::new();
        }
        let fields = esdm_sortable_fields(&self.element);
        if fields.is_empty() {
            self.filterable_fields()
        } else {
            fields
        }
    }

    /// How a collection query paginates: `Numbered | Offset | None`.
    pub fn page_style(&self) -> PageStyle {
        if self.element.kind != ElementKind::Query {
            return PageStyle::None;
        }
        esdm_page_style(&self.element)
    }

    /// The fixture specs of `ctx`'s read model, or `[]` when none/invalid,
    /// through `crate::context::fixture_functions` (the validator with the
    /// reserved-name and plural-collision function-name guards).
    pub fn fixture_specs(&self) -> Vec<FixtureFn> {
        let Some(rm) = &self.read_model else {
            return Vec::new();
        };
        let plural = self.render_or_panic("<domain_object>s");
        fixture_functions(rm, &self.composite, &plural).unwrap_or_default()
    }

    /// The materialized source for one field of the primary example, or
    /// `None` when the context holds no fixture.
    pub fn example_value(&self, name: &str) -> Option<String> {
        let fixture = self.fixture()?;
        fixture
            .attrs
            .iter()
            .find(|(field, _)| field == name)
            .map(|(_, source)| source.clone())
    }

    /// True when `ctx`'s read model declares usable fixture examples.
    pub fn fixtures(&self) -> bool {
        !self.fixture_specs().is_empty()
    }

    /// The generated-fixture reference for `ctx`'s constituent, from its
    /// primary example (the first in model order), or `None` when the read
    /// model declares no examples.
    pub fn fixture(&self) -> Option<FixtureRef> {
        let spec = self.fixture_specs().into_iter().next()?;
        Some(self.build_fixture_ref(&spec))
    }

    fn build_fixture_ref(&self, spec: &FixtureFn) -> FixtureRef {
        let fixtures_mod = crate::blueprints::fixtures::Fixtures::module_name(self);
        let factory_mod = crate::blueprints::factory::Factory::module_name(self);
        let local = fixtures_mod
            .split('.')
            .next_back()
            .unwrap_or(fixtures_mod.as_str())
            .to_string();
        let seed_local = factory_mod
            .split('.')
            .next_back()
            .unwrap_or(factory_mod.as_str())
            .to_string();
        FixtureRef {
            module: fixtures_mod,
            local,
            file: crate::blueprints::fixtures::Fixtures::module_file(self),
            function: spec.fname.clone(),
            plural: self.render_or_panic("<domain_object>s"),
            seed_module: factory_mod,
            seed_local,
            seed_file: crate::blueprints::factory::Factory::module_file(self),
            seed_function: crate::blueprints::factory::Factory::seed_name(self),
            seed_all_function: crate::blueprints::factory::Factory::seed_all_name(self),
            attrs: spec.attrs.clone(),
        }
    }

    /// The seed expression a single-row test uses to place the primary
    /// fixture.
    pub fn seed_expr(f: &FixtureRef) -> String {
        format!(
            "{}.{}({}.{}())",
            f.seed_local, f.seed_function, f.local, f.function
        )
    }

    /// The plural seed expression a collection test uses to place every
    /// fixture.
    pub fn seed_all_expr(f: &FixtureRef) -> String {
        format!(
            "{}.{}({}.{}())",
            f.seed_local, f.seed_all_function, f.local, f.plural
        )
    }

    // ---------------------------------------------------------- rendering

    /// Placeholder variables. Values are raw domain
    /// names; the engine re-cases them per notation.
    pub fn vars(&self) -> Vars {
        let mut v = Vars::new();
        v.insert("subdomain".into(), self.subdomain.clone());
        v.insert("composite".into(), self.composite.clone());
        v.insert("constituent".into(), self.constituent.clone());
        v.insert("domain_object".into(), self.constituent.clone());
        v.insert("public_api".into(), self.constituent.clone());
        v.insert("operation".into(), self.element.name.clone());
        v.insert("action".into(), self.element.name.clone());
        v.insert("entity".into(), self.constituent.clone());
        v.insert("value_object".into(), self.constituent.clone());
        v.insert("object".into(), self.constituent.clone());
        v.insert("jsonapi_type".into(), self.constituent.clone());
        if self.element.kind == ElementKind::Command {
            v.insert("command".into(), self.element.name.clone());
        }
        // `<Event>`: an event element names itself,
        // and anything else names the first event it publishes. A citizen
        // that publishes nothing (or nothing the model holds) leaves the
        // variable out, so a template naming `<Event>` stays unresolved.
        let event_name = match self.element.kind {
            ElementKind::Event => Some(self.element.name.clone()),
            _ => self.events.first().map(|ev| ev.name.clone()),
        };
        if let Some(name) = event_name {
            v.insert("event".into(), name);
        }
        if self.element.kind == ElementKind::Query {
            v.insert("query".into(), self.element.name.clone());
        }
        v
    }

    /// Prose slots, grown by the blueprints that need
    /// more prose than the read model does.
    pub fn slots(&self) -> Slots {
        let mut s = Slots::new();
        let desc = self.description();
        let doc_text = |instruction: &str| match desc {
            Some(d) if !d.is_empty() => d.to_string(),
            _ => format!("TODO: {instruction}"),
        };
        s.insert(
            "Describe what the command does to the aggregate, derived from the domain model."
                .to_string(),
            doc_text("describe what the command does to the aggregate"),
        );
        s.insert(
            "Describe what happened in the domain, derived from the event name.".to_string(),
            doc_text("describe what happened in the domain"),
        );
        s.insert(
            "describe the operation".to_string(),
            doc_text(&format!("describe the {} operation", self.element.name)),
        );
        s.insert(
            "describe the params".to_string(),
            format!("The {} attributes", self.constituent),
        );
        s.insert(
            "describe the result".to_string(),
            format!("The {}", self.constituent),
        );
        s.insert(
            "describe the domain object".to_string(),
            self.constituent.clone(),
        );
        s.insert("bounded_context".to_string(), self.bounded_context());
        // per-field type slots
        s.insert("field type".to_string(), "String.t()".to_string());
        for f in &self.fields {
            s.insert(format!("{} type", f.name), Self::elixir_type(f));
        }
        s
    }

    /// Fill a blueprint template; unresolvable
    /// placeholders abort the run with the names listed.
    pub fn render(&self, template: &str) -> Result<String, Vec<String>> {
        placeholders::render(template, &self.vars(), &self.slots())
    }

    /// `render` with extra vars — a plan driven from a related
    /// element overrides placeholders (`test_case::plan`'s `extra_vars`).
    pub fn render_with(&self, template: &str, extra_vars: &Vars) -> Result<String, Vec<String>> {
        let mut vars = self.vars();
        vars.extend(extra_vars.clone());
        placeholders::render(template, &vars, &self.slots())
    }

    /// Rendering with extra vars and extra prose slots together. The
    /// Bruno request file names its placeholder `<Operation Title>`, which
    /// the notation's space marks as a slot.
    pub fn render_full(
        &self,
        template: &str,
        extra_vars: &Vars,
        extra_slots: &Slots,
    ) -> Result<String, Vec<String>> {
        let mut vars = self.vars();
        vars.extend(extra_vars.clone());
        let mut slots = self.slots();
        slots.extend(extra_slots.clone());
        placeholders::render(template, &vars, &slots)
    }

    /// `render_or_panic` with the extra-vars and extra-slots override.
    pub fn render_or_panic_full(
        &self,
        template: &str,
        extra_vars: &Vars,
        extra_slots: &Slots,
    ) -> String {
        match self.render_full(template, extra_vars, extra_slots) {
            Ok(text) => text,
            Err(unknown) => {
                let listed = unknown
                    .iter()
                    .map(|u| format!("<{u}>"))
                    .collect::<Vec<_>>()
                    .join(", ");
                panic!("unresolved placeholder(s) in template: {listed}")
            }
        }
    }

    pub fn render_or_panic(&self, template: &str) -> String {
        self.render_or_panic_with(template, &Vars::new())
    }

    /// `render_or_panic` with the extra-vars override.
    pub fn render_or_panic_with(&self, template: &str, extra_vars: &Vars) -> String {
        match self.render_with(template, extra_vars) {
            Ok(text) => text,
            Err(unknown) => {
                let listed = unknown
                    .iter()
                    .map(|u| format!("<{u}>"))
                    .collect::<Vec<_>>()
                    .join(", ");
                panic!("unresolved placeholder(s) in template: {listed}")
            }
        }
    }

    /// The esdm scope's bounded context, for
    /// prose.
    pub(crate) fn bounded_context(&self) -> String {
        match self
            .element
            .scope
            .iter()
            .find(|(k, _)| k == "bounded-context")
        {
            Some((_, name)) => name.clone(),
            None => "the catalog".to_string(),
        }
    }
}

// ------------------------------------------------------------- inference

struct LocationParts {
    first: Option<String>,
    second: Option<String>,
}

/// `docs/domain-model/<subdomain>/<composite>/...` — the repo layout is the
/// architecture's source for subdomain and composite.
fn infer_location(element: &Element) -> LocationParts {
    let parts: Vec<String> = element
        .source
        .parent()
        .map(|dir| {
            dir.components()
                .map(|c| c.as_os_str().to_string_lossy().to_string())
                .collect()
        })
        .unwrap_or_default();
    let idx = parts.iter().position(|p| p == "domain-model");
    match idx {
        Some(i) => LocationParts {
            first: parts.get(i + 1).cloned(),
            second: parts.get(i + 2).cloned(),
        },
        None => LocationParts {
            first: None,
            second: None,
        },
    }
}

/// The constituent inferred from the element — the answer is the third
/// value of the returned tuple.
fn infer_constituent(model: &Model, element: &Element) -> ((), (), Option<String>) {
    let name = match element.kind {
        ElementKind::Aggregate | ElementKind::ReadModel | ElementKind::Entity => {
            Some(element.name.clone())
        }
        ElementKind::Command | ElementKind::Event | ElementKind::Feature => {
            element.aggregate_name().map(str::to_string)
        }
        ElementKind::Query => element.read_model_name().map(str::to_string),
        _ => None,
    };
    let _ = model;
    ((), (), name)
}

/// The operation declared for the element, never guessed.
pub fn derive_operation(model: &Model, element: &Element) -> Option<Operation> {
    use sparch_model::annotations as ann;
    match element.kind {
        ElementKind::Command => ann::declared_operation(element).and_then(|v| Operation::parse(&v)),
        ElementKind::Event => {
            let rm = model.read_model_for(element)?;
            ann::declared_effects(&rm)
                .into_iter()
                .find(|(event, _)| event == &element.name)
                .and_then(|(_, effect)| effect)
                .and_then(|v| Operation::parse(&v))
        }
        ElementKind::Query => ann::declared_query_operation(element)
            .and_then(|v| Operation::parse(&v))
            .or_else(|| {
                // `result.type: array` *is* a collection read
                let array = element
                    .doc
                    .get("result")
                    .and_then(|r| r.get("type"))
                    .and_then(|t| t.as_str())
                    == Some("array");
                Some(if array {
                    Operation::Collection
                } else {
                    Operation::Read
                })
            }),
        _ => Some(Operation::Create),
    }
}

/// The aggregate the element links to, with the self-links for aggregate- and
/// read-model-driven runs.
fn aggregate_link(model: &Model, element: &Element) -> Option<Element> {
    match element.kind {
        ElementKind::Aggregate => Some(element.clone()),
        ElementKind::ReadModel => {
            let projections = element
                .doc
                .get("projections")
                .and_then(|p| p.as_array())
                .cloned()
                .unwrap_or_default();
            projections
                .first()
                .and_then(|p| p.get("aggregate"))
                .and_then(|a| a.as_str())
                .and_then(|name| model.find(ElementKind::Aggregate, name))
        }
        _ => element
            .aggregate_name()
            .and_then(|name| model.find(ElementKind::Aggregate, name)),
    }
}

fn read_model_link(model: &Model, element: &Element) -> Option<Element> {
    if element.kind == ElementKind::ReadModel {
        return Some(element.clone());
    }
    model.read_model_for(element)
}

/// The context's `events:` field — the published names mapped through
/// the model's event lookup, with the names the model holds no event for
/// dropped. The list keeps `publishes` order, so the first entry is what
/// `<Event>` means for a citizen that is not itself an event.
fn published_events(model: &Model, element: &Element) -> Vec<Element> {
    element
        .publishes()
        .iter()
        .filter_map(|name| model.find(ElementKind::Event, name))
        .collect()
}

/// The `sortableFields` list on a query's
/// `parameters.properties.sort` entry, each name `to_string`'d. A model that
/// lists none leaves the `[]` answer for `sortable_fields` to
/// replace with its filterable fields.
fn esdm_sortable_fields(element: &Element) -> Vec<String> {
    let declared = element
        .doc
        .get("parameters")
        .and_then(|p| p.get("properties"))
        .and_then(|v| v.get("sort"))
        .and_then(|s| s.get("sortableFields"));
    match declared {
        Some(serde_json::Value::Array(items)) => items.iter().map(value_to_string).collect(),
        Some(serde_json::Value::Null) | None => Vec::new(),
        Some(single) => vec![value_to_string(single)],
    }
}

fn value_to_string(value: &serde_json::Value) -> String {
    match value {
        serde_json::Value::String(text) => text.clone(),
        other => other.to_string(),
    }
}

/// The model's page style: `None` when the query declares no `page`
/// parameter, `Offset` when it names `limit`/`offset`, `Numbered`
/// (`number`/`size`, and a bare `page` that states no properties) otherwise.
fn esdm_page_style(element: &Element) -> PageStyle {
    let Some(props) = element
        .doc
        .get("parameters")
        .and_then(|p| p.get("properties"))
        .and_then(|v| v.as_object())
    else {
        return PageStyle::None;
    };
    match props.get("page") {
        Some(page) if page.is_object() => page_style_of(page.get("properties")),
        _ => PageStyle::None,
    }
}

fn page_style_of(props: Option<&serde_json::Value>) -> PageStyle {
    match props.and_then(|v| v.as_object()) {
        Some(map) => {
            if map.keys().any(|k| k == "number" || k == "size") {
                PageStyle::Numbered
            } else if map.keys().any(|k| k == "limit" || k == "offset") {
                PageStyle::Offset
            } else {
                PageStyle::Numbered
            }
        }
        None => PageStyle::Numbered,
    }
}

/// The feature scenarios that exercise the element (by its `when`
/// command/query name), in model order.
fn scenarios(model: &Model, element: &Element) -> Vec<serde_json::Value> {
    model
        .elements
        .iter()
        .filter(|f| f.kind == ElementKind::Feature)
        .flat_map(|f| {
            f.doc
                .get("scenarios")
                .and_then(|s| s.as_array())
                .cloned()
                .unwrap_or_default()
        })
        .filter(|scenario| {
            let when = scenario.get("when");
            when.and_then(|w| w.get("command")).and_then(|c| c.as_str())
                == Some(element.name.as_str())
                || when.and_then(|w| w.get("query")).and_then(|q| q.as_str())
                    == Some(element.name.as_str())
        })
        .collect()
}

/// Canonical model order plus the generated `id`
/// for command-driven contexts.
fn fields_for(
    element: &Element,
    operation: Option<&Operation>,
    aggregate: Option<&Element>,
) -> Vec<Befield> {
    let mut fields: Vec<Befield> = sparch_model::fields(element)
        .iter()
        .map(Befield::from_field)
        .collect();
    let op = operation.copied();
    let wants_id = matches!(
        op,
        Some(Operation::Create) | Some(Operation::Update) | Some(Operation::Delete)
    );
    if wants_id
        && !fields.iter().any(|f| f.name == "id")
        && let Some(mut id) = generated_id(aggregate)
    {
        id.internal = op == Some(Operation::Create);
        fields.insert(0, id);
    }
    fields
}

/// The aggregate's `identifiedBy` generator
/// decides whether the id is a uuid.
fn generated_id(aggregate: Option<&Element>) -> Option<Befield> {
    let doc = aggregate?.doc.get("identifiedBy")?;
    let format = if doc.get("generator").and_then(|g| g.as_str()) == Some("uuid") {
        Some("uuid".to_string())
    } else {
        None
    };
    Some(Befield {
        name: "id".to_string(),
        ty: "string".to_string(),
        format,
        description: Some("Unique identifier".to_string()),
        required: true,
        internal: false,
        relation: None,
    })
}

/// Invariants and constraints through the
/// pattern registry, with the citizen-realizable filter for unresolved
/// rules and the sorted outputs.
fn validators_for(
    model: &Model,
    element: &Element,
    aggregate: Option<&Element>,
    fields: &[Befield],
    constituent: &str,
) -> (Vec<Validator>, Vec<(String, String)>) {
    let mut rules: Vec<serde_json::Value> = Vec::new();
    if let Some(agg) = aggregate {
        rules.extend(agg.invariants());
    }
    rules.extend(element.constraints());
    // dedupe by name, first occurrence wins — Elixir's `Enum.uniq_by`
    let mut seen: Vec<String> = Vec::new();
    rules.retain(|r| {
        let name = r
            .get("name")
            .and_then(|n| n.as_str())
            .unwrap_or("")
            .to_string();
        if seen.contains(&name) {
            false
        } else {
            seen.push(name);
            true
        }
    });

    let field_names: Vec<String> = fields.iter().map(|f| f.name.clone()).collect();
    let (mut validators, unresolved_rules) =
        sparch_model::invariants::resolve_all(&rules, &field_names, constituent);

    // a rule that names a field of any citizen element is noise about a run,
    // not a gap in the model; only rules naming nothing anywhere stay reported.
    let citizen = citizen_field_names(model, element, aggregate, &field_names);
    let unresolved: Vec<(String, String)> = unresolved_rules
        .into_iter()
        .filter(|rule| {
            let text = format!(
                "{} {}",
                rule.get("name").and_then(|n| n.as_str()).unwrap_or(""),
                rule.get("rule").and_then(|r| r.as_str()).unwrap_or("")
            );
            !citizen.iter().any(|field| names_word(&text, field))
        })
        .map(|rule| {
            (
                rule.get("name")
                    .and_then(|n| n.as_str())
                    .unwrap_or("")
                    .to_string(),
                rule.get("rule")
                    .and_then(|r| r.as_str())
                    .unwrap_or("")
                    .to_string(),
            )
        })
        .collect();

    validators.sort_by(|a, b| a.name.cmp(&b.name));
    let mut unresolved = unresolved;
    unresolved.sort_by(|a, b| a.0.cmp(&b.0));
    (validators, unresolved)
}

fn citizen_field_names(
    model: &Model,
    element: &Element,
    aggregate: Option<&Element>,
    own: &[String],
) -> Vec<String> {
    let mut names: Vec<String> = own.to_vec();
    let mut sources: Vec<Element> = vec![element.clone()];
    if let Some(agg) = aggregate {
        sources.push(agg.clone());
        sources.extend(model.commands_of(&agg.name));
    }
    if let Some(rm) = model.read_model_for(element) {
        sources.push(rm);
    }
    for source in sources {
        for f in sparch_model::fields(&source) {
            names.push(f.name);
        }
    }
    names.sort();
    names.dedup();
    names
}

/// The code form of one example value:
/// a fixture key → `UUID.uuid5(:dns, key)`; a `*_id` field whose value is
/// neither a key nor a UUID → wrapped as well (the fail-safe reading);
/// anything else → the literal, as `inspect` source.
fn materialize_example(field: &str, value: &serde_json::Value) -> String {
    if let Some(text) = value.as_str() {
        if sparch_model::fixtures::fixture_key(text) {
            return uuid_expr(text);
        }
        if sparch_model::has_id_tail(field) && !canonical_uuid(text) {
            return uuid_expr(text);
        }
    }
    crate::templates::inspect_value(value)
}

fn uuid_expr(key: &str) -> String {
    format!(
        "UUID.uuid5(:dns, {})",
        crate::templates::inspect_string(key)
    )
}

/// A canonical dash-separated UUID string.
fn canonical_uuid(value: &str) -> bool {
    let groups: Vec<usize> = value.split('-').map(|g| g.chars().count()).collect();
    groups.len() == 5
        && groups == vec![8, 4, 4, 4, 12]
        && value.chars().all(|c| c.is_ascii_hexdigit() || c == '-')
}

const ELIXIR_NONAMES: [&str; 14] = [
    "do", "end", "when", "case", "cond", "and", "or", "not", "in", "fn", "else", "true", "false",
    "nil",
];

/// One example, prepared for rendering into BE fixture code: the fixture key,
/// its parts, the function name it produces, and the materialized attributes
/// in schema field order.
#[derive(Clone, Debug)]
pub struct FixtureFn {
    pub key: String,
    pub parts: sparch_model::fixtures::FixtureKey,
    pub fname: String,
    pub attrs: Vec<(String, String)>,
}

/// A generated fixture row, named from every angle a test needs: the fixture
/// module and its file, the mnemonic and plural function names, and the
/// composite factory that seeds them.
#[derive(Clone, Debug)]
pub struct FixtureRef {
    pub module: String,
    pub local: String,
    pub file: String,
    pub function: String,
    pub plural: String,
    pub seed_module: String,
    pub seed_local: String,
    pub seed_file: String,
    pub seed_function: String,
    pub seed_all_function: String,
    pub attrs: Vec<(String, String)>,
}

/// The key's mnemonic, snake-cased.
pub fn function_name(key: &str) -> String {
    let (_composite, _read_model, mnemonic) =
        sparch_model::fixtures::parse_key(key).unwrap_or_else(|reason| panic!("{reason}"));
    mnemonic.replace('-', "_")
}

/// Validate a read model's examples and
/// prepare renderable specs, reporting *every* violation, never just the
/// first. `plural` is the aggregate function the generated file will define;
/// no mnemonic may shadow an Elixir keyword or produce that name.
pub fn fixture_functions(
    element: &Element,
    composite: &str,
    plural: &str,
) -> Result<Vec<FixtureFn>, Vec<String>> {
    let declared = sparch_model::fields(element);
    let properties: Vec<&str> = declared.iter().map(|f| f.name.as_str()).collect();
    let required: Vec<&str> = declared
        .iter()
        .filter(|f| f.required)
        .map(|f| f.name.as_str())
        .collect();
    let source = element.source.display().to_string();

    let mut specs: Vec<FixtureFn> = Vec::new();
    let mut errors: Vec<String> = Vec::new();

    for example in sparch_model::fixtures::examples_of(element) {
        let Some(object) = example.as_object() else {
            continue;
        };
        let mut found: Vec<String> = Vec::new();
        let label = example_label(object);

        for key in object.keys() {
            if !properties.contains(&key.as_str()) {
                found.push(format!(
                    "example {label} carries \"{key}\", which the schema does not declare"
                ));
            }
        }
        for name in &required {
            if !object.contains_key(*name) {
                found.push(format!(
                    "example {label} is missing required property \"{name}\""
                ));
            }
        }
        let id = object.get("id");
        let key_text = match id {
            None => {
                found.push(format!(
                    "example {label} carries no id — fixtures name themselves with a fixture key"
                ));
                None
            }
            Some(serde_json::Value::String(text)) => {
                let text = text.clone();
                match sparch_model::fixtures::parse_key(&text) {
                    Err(reason) => {
                        found.push(reason);
                        None
                    }
                    Ok(parts) => {
                        if parts.0 != composite || parts.1 != element.name {
                            found.push(format!(
                                "fixture key {} names {}/{}, but this read model lives in {}/{} — a key must name its own home",
                                crate::templates::inspect_string(&text),
                                crate::templates::inspect_string(&parts.0),
                                crate::templates::inspect_string(&parts.1),
                                crate::templates::inspect_string(composite),
                                crate::templates::inspect_string(&element.name),
                            ));
                        }
                        Some(text)
                    }
                }
            }
            Some(_) => {
                found.push("a fixture key must be a string".to_string());
                None
            }
        };
        for (field, value) in object {
            let Some(text) = value.as_str() else { continue };
            if sparch_model::has_id_tail(field)
                && !sparch_model::fixtures::fixture_key(text)
                && !canonical_uuid(text)
            {
                found.push(format!(
                    "reference value {} is neither a fixture key nor a UUID",
                    crate::templates::inspect_string(text)
                ));
            }
        }
        if let Some(key) = &key_text
            && sparch_model::fixtures::fixture_key(key)
        {
            let fname = function_name(key);
            if ELIXIR_NONAMES.contains(&fname.as_str()) {
                found.push(format!(
                    "{fname}/0 would shadow an Elixir keyword — rename the mnemonic"
                ));
            } else if fname == plural {
                found.push(format!(
                    "fixture key {} would define {plural}/0, colliding with the aggregate function of the same file",
                    crate::templates::inspect_string(key)
                ));
            }
        }

        match found.is_empty() {
            true => specs.push(fixture_fn(object, &properties)),
            false => errors.extend(
                found
                    .into_iter()
                    .map(|message| format!("{source}: {message}")),
            ),
        }
    }

    if !errors.is_empty() {
        return Err(errors);
    }
    let mut counts: Vec<(String, usize)> = Vec::new();
    for spec in &specs {
        if let Some((_, count)) = counts.iter_mut().find(|(name, _)| *name == spec.fname) {
            *count += 1;
        } else {
            counts.push((spec.fname.clone(), 1));
        }
    }
    let duplicates: Vec<String> = counts
        .iter()
        .filter(|(_, count)| *count > 1)
        .map(|(fname, _)| {
            format!("{source}: two examples both name function {fname}/0 — mnemonics must differ")
        })
        .collect();
    match duplicates.is_empty() {
        true => Ok(specs),
        false => Err(duplicates),
    }
}

fn fixture_fn(
    example: &serde_json::Map<String, serde_json::Value>,
    properties: &[&str],
) -> FixtureFn {
    let key = example["id"].as_str().unwrap_or_default().to_string();
    let parts = sparch_model::fixtures::parse_key(&key).unwrap_or_else(|reason| panic!("{reason}"));
    let attrs = properties
        .iter()
        .filter(|name| example.contains_key(**name))
        .map(|name| {
            (
                (*name).to_string(),
                materialize_example(name, &example[*name]),
            )
        })
        .collect();
    FixtureFn {
        key: key.clone(),
        parts,
        fname: function_name(&key),
        attrs,
    }
}

/// The key when there is one, else the
/// title, else `<unnamed>`, always as `inspect` source.
fn example_label(example: &serde_json::Map<String, serde_json::Value>) -> String {
    match example.get("id") {
        Some(serde_json::Value::String(id)) => crate::templates::inspect_string(id),
        _ => match example.get("title") {
            Some(title) => crate::templates::inspect_value(title),
            None => "\"<unnamed>\"".to_string(),
        },
    }
}

/// Word-boundary containment, as in the invariant patterns.
pub fn names_word(text: &str, field: &str) -> bool {
    let text = text.to_lowercase();
    let field = field.to_lowercase();
    if field.is_empty() {
        return false;
    }
    let is_word = |c: char| c.is_alphanumeric() || c == '_';
    let hay: Vec<char> = text.chars().collect();
    let needle: Vec<char> = field.chars().collect();
    hay.windows(needle.len())
        .enumerate()
        .filter(|(_, w)| **w == needle[..])
        .any(|(i, _)| {
            let before_ok = i == 0 || !is_word(hay[i - 1]);
            let after = i + needle.len();
            let after_ok = after == hay.len() || !is_word(hay[after]);
            before_ok && after_ok
        })
}
