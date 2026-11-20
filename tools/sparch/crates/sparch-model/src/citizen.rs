//! The FE citizen: one read model, seen the way the frontend needs it.
//!
//! Where the BE `SpGen.Context` assembles variables for Elixir template
//! rendering, `Citizen` assembles typed facts for the TypeScript
//! blueprints: properties with their TS names and types, commands with
//! their effects (declared, never guessed), queries with their read kind,
//! fixtures resolved against the citizens they reference, and the two
//! architecture paths every file hangs from.

use crate::{
    Element, ElementKind, Model,
    annotations::{declared_effects, declared_query_operation},
    fields::{self, Cardinality, Field},
    fixtures::{self, FixtureSpec},
    naming::{Case, Name},
};
use serde_json::Value;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PropertyKind {
    Identifier,
    Slug,
    Attribute,
    Reference,
}

#[derive(Clone, Debug)]
pub struct RelationView {
    /// Read model name of the target (`apparatus`).
    pub target: String,
    /// Composite the target lives in (`equipment`) — where its barrel is.
    pub target_composite: String,
    /// Pascal TS type name of the target (`Apparatus`).
    pub target_type: String,
    pub cardinality: Cardinality,
    /// Explicit inverse property name, or `None` = unidirectional.
    pub inverse: Option<String>,
}

#[derive(Clone, Debug)]
pub struct Property {
    pub field: Field,
    /// TS property name: from the field's own words, or — for
    /// relationships — from the relation keyword's `to`
    /// (`apparatusId` with `to: apparatus` → `apparatus`).
    pub ts_name: String,
    /// `ID`, `Slug`, `string`, `Apparatus`, …
    pub ts_type: String,
    pub optional: bool,
    pub kind: PropertyKind,
    /// The `readOnly` fact: part of the interface (it arrives on the
    /// wire), never writable — no `XFields` member, no payload key.
    pub read_only: bool,
    pub relation: Option<RelationView>,
}

#[derive(Clone, Debug)]
pub struct Command {
    pub element: Element,
    pub name: String,
    /// `catalogPosition` — the action function.
    pub fn_name: String,
    /// `CatalogPosition` — Data type and ability prefix.
    pub pascal: String,
    /// The effect this command's event has on the read model, from the
    /// model's own `spgen.operation.<event>` annotations: `create`,
    /// `update`, `delete`, `none` — or `None` when nobody declared one.
    pub effect: Option<String>,
    /// Roles the ability checks: the command's actors plus `admin`.
    pub roles: Vec<String>,
    pub data_fields: Vec<Field>,
    /// TS names of optional command fields that map to a *writable*
    /// citizen property (attributes **and** relationships) — the
    /// `WithPartial<…>` list. Command fields mapping to a `readOnly` or
    /// `writeOnly` property, or to nothing, are ignored: there is no
    /// tail to type them with, and a payload member that is not a
    /// resource field means the model is broken, not the renderer.
    pub partials: Vec<String>,
    /// `athlete/positions/catalog-position` — command routes nest under the
    /// plural collection scope (confirmed against the BE router).
    pub path: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum QueryKind {
    Read,
    Collection,
}

#[derive(Clone, Debug)]
pub struct Query {
    pub element: Element,
    pub name: String,
    /// `listPositions` / `readPosition` — named from the element verbatim.
    pub fn_name: String,
    /// Pascal of the fn name tail: `Positions`/`Position` for endpoint names.
    pub kind: QueryKind,
    pub actors: Vec<String>,
    /// `athlete/positions` — the collection path.
    pub path: String,
    /// Read queries address one resource: the joined `oneOf` parameter
    /// names (`id`, `slug` → `idOrSlug`).
    pub param: Option<String>,
    /// Read queries: the `oneOf` parameter names as citizen property
    /// names — the declared addressing of this access path.
    pub params: Vec<String>,
}

/// How a citizen is addressed, as declared by its read queries' `oneOf`
/// parameters — "a query is the logical access path to one view", so the
/// query, not a naming heuristic, says how to find one.
#[derive(Clone, Debug)]
pub struct Lookup {
    /// Every declared addressing property (ts names), sorted.
    pub params: Vec<String>,
    /// The friendly one for selectors, options and mocks: a non-`id`
    /// param when one is declared (a canonical `slug`), else `id`.
    pub preferred: String,
}

#[derive(Clone, Debug)]
pub enum FixtureEntry {
    /// The fixture key itself materializes as the resource id.
    Identifier { ts_name: String, key: String },
    /// A plain example value, rendered as a TS literal.
    Attribute { ts_name: String, ts_value: String },
    /// A reference to another fixture: the const name and where it lives.
    Reference {
        ts_name: String,
        target_const: String,
        target_composite: String,
        /// The fixture key of the target (`equipment:instrument:unicycle`) —
        /// source of the gate path onto the target's fixtures file.
        target_key: String,
    },
}

#[derive(Clone, Debug)]
pub struct FixtureView {
    pub spec: FixtureSpec,
    /// Convenience copy of `spec.const_name` for the blueprints.
    pub const_name: String,
    pub entries: Vec<FixtureEntry>,
}

#[derive(Clone, Debug)]
pub struct Citizen {
    pub element: Element,
    /// App + model axis: `catalog` (apps/catalog).
    pub subdomain: String,
    /// Slice directory: `athlete` (src/athlete).
    pub composite: String,
    /// The read model name: `position`.
    pub constituent: String,
    pub type_name: String,
    pub properties: Vec<Property>,
    pub commands: Vec<Command>,
    pub queries: Vec<Query>,
    pub fixtures: Vec<FixtureView>,
    /// Every human actor name, sorted (`admin`, `guest`, `user`).
    pub roles: Vec<String>,
    /// Declared addressing from the read queries, if any.
    pub lookup: Option<Lookup>,
}

impl Citizen {
    pub fn build(model: &Model, element: &Element) -> Result<Self, String> {
        let segments = path_segments(element);
        let (subdomain, composite) = match (segments.first(), segments.get(1)) {
            (Some(sub), Some(comp)) => (sub.clone(), comp.clone()),
            _ => {
                return Err(format!(
                    "{} is not under a subdomain/composite layout",
                    element.source.display()
                ));
            }
        };

        let type_name = Name::parse(&element.name).render(Case::Pascal);
        // The interface is the read model's shape minus writeOnly
        // fields — the FE ignores them entirely: they never arrive on
        // the wire, so they get no property, no fixture, no arg.
        let rm_fields = fields::fields(element);
        let write_only: Vec<String> = rm_fields
            .iter()
            .filter(|f| f.write_only)
            .map(|f| f.name.clone())
            .collect();
        let properties = build_properties(model, &rm_fields);
        let commands = build_commands(model, element, &composite, &properties);
        let queries = build_queries(model, element, &composite, &properties);

        // addressing is declared, never guessed: the read queries' `oneOf`
        // params name the addressing properties
        let mut params: Vec<String> = Vec::new();
        for query in &queries {
            for p in &query.params {
                if !params.contains(p) {
                    params.push(p.clone());
                }
            }
        }
        params.sort();
        let lookup = if params.is_empty() {
            None
        } else {
            let preferred = params
                .iter()
                .find(|p| p.as_str() != "id")
                .cloned()
                .unwrap_or_else(|| "id".to_string());
            Some(Lookup { params, preferred })
        };

        let plural_const = Name::parse(&element.name).render_plural(Case::Screaming);
        let fixture_result = fixtures::validate(element, &composite, &plural_const);
        let fixtures = match fixture_result {
            Ok(specs) => specs
                .into_iter()
                .map(|spec| FixtureView {
                    const_name: spec.const_name.clone(),
                    entries: build_entries(model, &properties, &spec, &write_only),
                    spec,
                })
                .collect(),
            Err(_) => vec![],
        };

        let mut roles: Vec<String> = model
            .elements
            .iter()
            .filter(|e| e.kind == ElementKind::Actor)
            .map(|e| e.name.clone())
            .collect();
        roles.sort();
        roles.dedup();

        Ok(Citizen {
            element: element.clone(),
            subdomain,
            composite,
            constituent: element.name.clone(),
            type_name,
            properties,
            commands,
            queries,
            fixtures,
            roles,
            lookup,
        })
    }

    /// Validation errors of the read model's examples, for the report.
    pub fn fixture_errors(element: &Element) -> Vec<String> {
        let segments = path_segments(element);
        let composite = segments.get(1).cloned().unwrap_or_default();
        let plural_const = Name::parse(&element.name).render_plural(Case::Screaming);
        fixtures::validate(element, &composite, &plural_const)
            .err()
            .unwrap_or_default()
    }

    /// `athlete/positions` — the JSON:API collection path.
    pub fn resource_path(&self) -> String {
        format!(
            "{}/{}",
            self.composite,
            Name::parse(&self.constituent).plural_kebab()
        )
    }

    /// Pascal of a param for `find{Type}By{Pascal}` naming.
    pub fn lookup_pascal(&self) -> Option<String> {
        self.lookup
            .as_ref()
            .map(|l| Name::parse(&l.preferred).render(Case::Pascal))
    }

    pub fn property(&self, ts_name: &str) -> Option<&Property> {
        self.properties.iter().find(|p| p.ts_name == ts_name)
    }

    /// The writable fields: neither the identifier nor a readOnly
    /// property — attributes *and* relationships. This is the `XFields`
    /// pick list.
    pub fn mutable_fields(&self) -> Vec<&Property> {
        self.properties
            .iter()
            .filter(|p| p.kind != PropertyKind::Identifier && !p.read_only)
            .collect()
    }

    pub fn relations(&self) -> Vec<&Property> {
        self.properties
            .iter()
            .filter(|p| p.kind == PropertyKind::Reference)
            .collect()
    }
}

/// `docs/domain-model/<subdomain>/<composite>/...` — the model layout is the
/// architecture's source for subdomain and composite, ported from
/// `Context.model_dir_segments/1`.
fn path_segments(element: &Element) -> Vec<String> {
    let parts: Vec<String> = element
        .source
        .components()
        .map(|c| c.as_os_str().to_string_lossy().to_string())
        .collect();
    match parts.iter().position(|p| p == "domain-model") {
        Some(index) => parts[index + 1..].to_vec(),
        None => vec![],
    }
}

fn build_properties(model: &Model, rm_fields: &[Field]) -> Vec<Property> {
    rm_fields
        .iter()
        .filter(|field| !field.write_only)
        .cloned()
        .map(|field| {
            // The relation keyword is the identifier: a relationship's TS
            // name and type come from `to`, never from the field's own
            // spelling — `primaryEquipmentId` with `to: apparatus` is
            // `apparatus?: Apparatus`, not a stripped field name.
            let is_reference = field.relation.is_some();
            let relation = field.relation.as_ref().map(|rel| {
                let target = model.find(ElementKind::ReadModel, &rel.to);
                let target_composite = target
                    .as_ref()
                    .map(|t| path_segments(t).get(1).cloned().unwrap_or_default())
                    .unwrap_or_default();
                RelationView {
                    target: rel.to.clone(),
                    target_composite,
                    target_type: Name::parse(&rel.to).render(Case::Pascal),
                    cardinality: rel.cardinality,
                    inverse: rel.inverse.clone(),
                }
            });
            let ts_name = match &relation {
                Some(rel) => Name::parse(&rel.target).render(Case::Camel),
                None => Name::parse(&field.name).render(Case::Camel),
            };

            let ts_type = if field.name == "id" {
                "ID".to_string()
            } else if let Some(relation) = &relation {
                match relation.cardinality {
                    Cardinality::One => relation.target_type.clone(),
                    Cardinality::Many => format!("{}[]", relation.target_type),
                }
            } else if ts_name == "slug" {
                // slug detection is exact: the canonical key is `slug`
                // or there is none
                "Slug".to_string()
            } else {
                ts_base_type(&field.ty)
            };

            let kind = if field.name == "id" {
                PropertyKind::Identifier
            } else if is_reference {
                PropertyKind::Reference
            } else if ts_type == "Slug" {
                PropertyKind::Slug
            } else {
                PropertyKind::Attribute
            };

            Property {
                ts_name,
                optional: !field.required,
                kind,
                relation,
                read_only: field.read_only,
                ts_type,
                field,
            }
        })
        .collect()
}

fn ts_base_type(ty: &str) -> String {
    match ty {
        "string" => "string".into(),
        "integer" | "number" => "number".into(),
        "boolean" => "boolean".into(),
        "array" => "unknown[]".into(),
        _ => "unknown".into(),
    }
}

fn build_commands(
    model: &Model,
    read_model: &Element,
    composite: &str,
    properties: &[Property],
) -> Vec<Command> {
    let effects = declared_effects(read_model);
    let collection = format!(
        "{composite}/{}",
        Name::parse(&read_model.name).plural_kebab()
    );

    model
        .commands_of(&read_model.name)
        .into_iter()
        .map(|element| {
            let name = Name::parse(&element.name);
            let published = element.publishes();
            // the effect the read model declares for the event this command
            // publishes — declared, never guessed
            let effect = published
                .iter()
                .find_map(|event| effects.iter().find(|(e, _)| e == event))
                .and_then(|(_, effect)| effect.clone());

            let mut roles = element.actors();
            if !roles.iter().any(|r| r == "admin") {
                roles.push("admin".to_string());
            }

            let data_fields = fields::fields(&element);
            // `WithPartial` keys: the command's optional fields that map
            // to a writable citizen property — attributes *and*
            // relationships, named as the citizen names them. Fields
            // mapping to a readOnly or writeOnly property, or to nothing,
            // are ignored: the model owns that breakage, not the renderer.
            let mut partials = Vec::new();
            for f in &data_fields {
                if f.required {
                    continue;
                }
                if let Some(p) = properties.iter().find(|p| p.field.name == f.name)
                    && !p.read_only
                {
                    partials.push(p.ts_name.clone());
                }
            }

            Command {
                fn_name: name.render(Case::Camel),
                pascal: name.render(Case::Pascal),
                path: format!("{collection}/{}", element.name),
                name: element.name.clone(),
                element,
                effect,
                roles,
                data_fields,
                partials,
            }
        })
        .collect()
}

fn build_queries(
    model: &Model,
    read_model: &Element,
    composite: &str,
    properties: &[Property],
) -> Vec<Query> {
    let collection = format!(
        "{composite}/{}",
        Name::parse(&read_model.name).plural_kebab()
    );

    model
        .queries_of(&read_model.name)
        .into_iter()
        .map(|element| {
            let kind = match declared_query_operation(&element) {
                Some(op) if op == "collection" => QueryKind::Collection,
                Some(op) if op == "read" => QueryKind::Read,
                _ if element
                    .doc
                    .get("result")
                    .and_then(|r| r.get("type"))
                    .and_then(Value::as_str)
                    == Some("array") =>
                {
                    QueryKind::Collection
                }
                _ => QueryKind::Read,
            };
            let one_of: Vec<String> = element
                .doc
                .get("parameters")
                .and_then(|p| p.get("oneOf"))
                .and_then(Value::as_array)
                .map(|branches| {
                    branches
                        .iter()
                        .flat_map(|branch| {
                            branch
                                .get("properties")
                                .and_then(Value::as_object)
                                .map(|props| props.keys().cloned().collect::<Vec<_>>())
                                .unwrap_or_default()
                        })
                        .collect()
                })
                .unwrap_or_default();
            let param = (kind == QueryKind::Read).then(|| {
                if one_of.is_empty() {
                    "id".to_string()
                } else {
                    // `id`, `slug` → `idOrSlug` — the BE read-param convention
                    let mut parts = one_of
                        .iter()
                        .map(|n| Name::parse(n).render(Case::Pascal))
                        .collect::<Vec<_>>()
                        .into_iter();
                    match parts.next() {
                        Some(first) => {
                            let mut lower = first.clone();
                            lower[..1].make_ascii_lowercase();
                            for p in parts {
                                lower.push_str("Or");
                                lower.push_str(&p);
                            }
                            lower
                        }
                        None => "id".to_string(),
                    }
                }
            });
            // the declared addressing, as citizen property names
            let params: Vec<String> = if kind == QueryKind::Read {
                one_of
                    .iter()
                    .map(|wire| {
                        properties
                            .iter()
                            .find(|p| &p.field.name == wire || p.ts_name == *wire)
                            .map(|p| p.ts_name.clone())
                            .unwrap_or_else(|| ts_of_field_name(wire))
                    })
                    .collect()
            } else {
                vec![]
            };

            Query {
                fn_name: Name::parse(&element.name).render(Case::Camel),
                kind,
                path: collection.clone(),
                name: element.name.clone(),
                actors: element.actors(),
                param,
                params,
                element,
            }
        })
        .collect()
}

fn ts_of_field_name(name: &str) -> String {
    Name::parse(name).render(Case::Camel)
}

fn build_entries(
    model: &Model,
    properties: &[Property],
    spec: &FixtureSpec,
    write_only: &[String],
) -> Vec<FixtureEntry> {
    let mut entries = Vec::new();
    for (name, value) in &spec.properties {
        // writeOnly fields are ignored by the frontend entirely — an
        // example's value for them has nowhere to land
        if write_only.iter().any(|w| w == name) {
            continue;
        }
        let property = properties.iter().find(|p| &p.field.name == name);
        let ts_name = property
            .map(|p| p.ts_name.clone())
            .unwrap_or_else(|| ts_of_field_name(name));

        if name == "id"
            && let Value::String(key) = value
        {
            entries.push(FixtureEntry::Identifier {
                ts_name,
                key: key.clone(),
            });
            continue;
        }
        if let Some(property) = property
            && property.kind == PropertyKind::Reference
            && let Value::String(key) = value
        {
            let target_const = fixtures::parse_key(key)
                .map(|(_, _, mnemonic)| Name::parse(&mnemonic).render(Case::Screaming))
                .unwrap_or_default();
            let target_composite = fixtures::parse_key(key)
                .map(|(composite, target_rm, _)| {
                    model
                        .find(ElementKind::ReadModel, &target_rm)
                        .map(|element| {
                            path_segments(&element)
                                .get(1)
                                .cloned()
                                .unwrap_or_else(|| composite.clone())
                        })
                        .unwrap_or(composite)
                })
                .unwrap_or_default();
            entries.push(FixtureEntry::Reference {
                ts_name,
                target_const,
                target_composite,
                target_key: key.clone(),
            });
            continue;
        }
        entries.push(FixtureEntry::Attribute {
            ts_value: ts_literal(value),
            ts_name,
        });
    }
    entries
}

pub fn ts_literal(value: &Value) -> String {
    match value {
        Value::String(text) => format!("'{}'", text.replace('\'', "\\'")),
        other => other.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::Model;
    use std::path::Path;

    fn corpus() -> Model {
        let root = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../fixtures/domain-model")
            .canonicalize()
            .expect("shared fixture corpus");
        Model::load(&root)
    }

    #[test]
    fn position_citizen_is_the_model_read_faithfully() {
        let model = corpus();
        let read_model = model
            .resolve("read-model.position", &[])
            .expect("position read model");
        let citizen = Citizen::build(&model, &read_model).expect("citizen");

        assert_eq!(citizen.type_name, "Position");
        assert_eq!(citizen.composite, "athlete");

        // x-esdm-relation drives the property kind and the target barrel
        let apparatus = citizen
            .properties
            .iter()
            .find(|p| p.ts_name == "apparatus")
            .expect("apparatus property");
        assert_eq!(apparatus.kind, PropertyKind::Reference);
        let relation = apparatus.relation.as_ref().expect("relation");
        assert_eq!(relation.target, "apparatus");
        assert_eq!(relation.target_composite, "equipment");

        // the `WithPartial` keys: optional command fields that map to a
        // writable citizen property — attributes *and* relationships.
        // The command's `slug` maps by name to the readOnly `slug`, so
        // it is ignored (no tail exists to hide that model collision in).
        let catalog = citizen
            .commands
            .iter()
            .find(|c| c.name == "catalog-position")
            .expect("catalog-position");
        assert_eq!(
            catalog.partials,
            vec![
                "apparatus".to_string(),
                "description".to_string(),
                "instrument".to_string()
            ]
        );
        assert_eq!(catalog.effect.as_deref(), Some("create"));
        assert_eq!(catalog.path, "athlete/positions/catalog-position");
        assert_eq!(catalog.fn_name, "catalogPosition");

        // provenance flags: slug is server-managed, and the writable
        // `XFields` pick list reflects it — no slug, no id
        let slug = citizen
            .properties
            .iter()
            .find(|p| p.ts_name == "slug")
            .expect("slug property");
        assert!(slug.read_only);
        let fields: Vec<&str> = citizen
            .mutable_fields()
            .iter()
            .map(|p| p.ts_name.as_str())
            .collect();
        assert_eq!(
            fields,
            ["title", "rawSlug", "apparatus", "description", "instrument"]
        );
        assert_eq!(catalog.effect.as_deref(), Some("create"));
        assert_eq!(catalog.path, "athlete/positions/catalog-position");
        assert_eq!(catalog.fn_name, "catalogPosition");

        // query names come from the model verbatim
        let list = citizen
            .queries
            .iter()
            .find(|q| q.name == "list-positions")
            .expect("list-positions");
        assert_eq!(list.fn_name, "listPositions");
        assert_eq!(list.kind, QueryKind::Collection);
        let read = citizen
            .queries
            .iter()
            .find(|q| q.name == "read-position")
            .expect("read-position");
        assert_eq!(read.fn_name, "readPosition");
        assert_eq!(read.param.as_deref(), Some("idOrSlug"));
        assert_eq!(read.params, vec!["id".to_string(), "slug".to_string()]);

        // addressing is declared by the read query's oneOf; slug preferred
        let lookup = citizen.lookup.clone().expect("lookup from read-position");
        assert_eq!(lookup.params, vec!["id".to_string(), "slug".to_string()]);
        assert_eq!(lookup.preferred, "slug");

        // slug typing is exact — `slug` or nothing: raw_slug is a plain
        // string attribute, not a Slug, and gets no finder
        let raw = citizen
            .properties
            .iter()
            .find(|p| p.ts_name == "rawSlug")
            .expect("rawSlug property");
        assert_eq!(raw.ts_type, "string");
        assert_eq!(raw.kind, PropertyKind::Attribute);
    }
}
