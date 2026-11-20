//! The work item and its plan — the port of `SpGen.Unit` and `SpGen.FilePlan`.
//!
//! The unit is the unit of work: an identity, a presence check, a renderer,
//! a placement and optional gates. Plans are built per context run, so the
//! context-dependent parts (rendered text, gate paths, module wrappers) are
//! resolved into data here rather than threaded as closures over a context.

use crate::context::Context;
use crate::elixir::{ElixirFile, Rank};

/// A unit's identity — `SpGen.Unit.id`, rendered by `Report.unit_label/1`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum UnitId {
    Moduledoc,
    /// `{:moduledoc, role}` — the `@moduledoc` of a file whose unit id names
    /// the file's role (the handler's `{:moduledoc, :handler}`).
    ModuledocFor(String),
    Use(String),
    Import(String),
    Alias(String),
    Require(String),
    Behaviour(String),
    /// `{:derive, module}` — an `@derive` attribute naming a module.
    Derive(String),
    Attribute(String),
    /// `:moduletag` — the test file's `@moduletag` attribute.
    Moduletag,
    /// `{:test_alias, module}` — an alias owned by a test file contributor
    /// (`TestCaseFile.alias_unit`), distinct from a citizen's `{:alias, _}`.
    TestAlias(String),
    Field(String),
    Validates(String),
    Describe(String),
    Dispatch(String),
    Identify(String),
    /// `{:router_alias, module}` — an alias owned by the commanded router,
    /// distinct from a citizen's own `{:alias, _}`.
    RouterAlias(String),
    /// `{:middleware, name}` — one `middleware` entry of the commanded
    /// router.
    Middleware(String),
    /// `{:app_router, module}` — the router registration line of a
    /// commanded application.
    AppRouter(String),
    Project(String),
    /// `{:child, module}` — one entry of a supervisor's `children` list.
    Child(String),
    Operation(String),
    Plug(String),
    Route(String),
    /// `{:apply, event}` — one `apply/2` clause of an aggregate, keyed by
    /// the event it folds.
    Apply(String),
    /// `{:authorize, action}`, one policy clause keyed by the action atom
    /// its head matches.
    Authorize(String),
    Def(String, usize),
    Defs(String),
    /// `:schema_body`, `:tags` — a plain-atom unit id; `report.ex` labels an
    /// atom id with `Atom.to_string/1`.
    AtomId(String),
    WholeFile,
}

impl UnitId {
    pub fn label(&self) -> String {
        match self {
            UnitId::Moduledoc => "moduledoc".to_string(),
            // report.ex `unit_label({macro, key})` — "#{macro} #{key}"
            UnitId::ModuledocFor(role) => format!("moduledoc {role}"),
            UnitId::Use(m) => format!("use {m}"),
            UnitId::Import(m) => format!("import {m}"),
            UnitId::Alias(m) => format!("alias {m}"),
            UnitId::Require(m) => format!("require {m}"),
            UnitId::Behaviour(m) => format!("behaviour {m}"),
            // report.ex `unit_label({macro, key})` — "#{macro} #{key}"
            UnitId::Derive(m) => format!("derive {m}"),
            UnitId::Attribute(a) => format!("@{a}"),
            // report.ex `unit_label(id)` for an atom — Atom.to_string/1
            UnitId::Moduletag => "moduletag".to_string(),
            UnitId::TestAlias(m) => format!("test_alias {m}"),
            UnitId::Field(f) => format!("field {f}"),
            UnitId::Validates(f) => format!("validates {f}"),
            UnitId::Describe(s) => format!("describe {s}"),
            UnitId::Dispatch(t) => format!("dispatch {t}"),
            UnitId::Identify(t) => format!("identify {t}"),
            UnitId::RouterAlias(m) => format!("router_alias {m}"),
            UnitId::Middleware(n) => format!("middleware {n}"),
            UnitId::AppRouter(m) => format!("app_router {m}"),
            UnitId::Project(t) => format!("project {t}"),
            // report.ex `unit_label({macro, key})` — "#{macro} #{key}"
            UnitId::Child(m) => format!("child {m}"),
            UnitId::Operation(t) => format!("operation {t}"),
            UnitId::Plug(t) => format!("plug {t}"),
            UnitId::Route(t) => format!("route {t}"),
            // report.ex `unit_label({:apply, event})` — "apply <event>"
            UnitId::Apply(t) => format!("apply {t}"),
            // report.ex `unit_label({macro, key})` — "#{macro} #{key}"
            UnitId::Authorize(a) => format!("authorize {a}"),
            UnitId::Def(name, arity) => format!("{name}/{arity}"),
            UnitId::Defs(name) => format!("defs {name}"),
            // report.ex `unit_label(id)` for an atom — `Atom.to_string/1`
            UnitId::AtomId(name) => name.clone(),
            UnitId::WholeFile => "whole file".to_string(),
        }
    }
}

/// Where a unit lands — the ports of the `SpGen.Merge` factories.
#[derive(Clone)]
pub enum Placement {
    /// `Merge.head(kind)` — into the directive block at its rank;
    /// `Merge.alias_of` also carries the alphabetical sort key.
    Head {
        rank: Rank,
        alias_sort_key: Option<String>,
    },
    /// `Merge.inside(macro, wrapper, before_trailing)` — into the first
    /// top-level call's `do` block; the wrapper materializes a missing
    /// block (`{unit}` marks the unit text in the wrapper template).
    Inside {
        macro_name: String,
        wrapper: Option<String>,
        before_trailing: Option<String>,
    },
    /// `Merge.body_end()` — append at the end of the module body.
    BodyEnd,
    /// `Merge.before_helpers()` — insert before the first `defp` group
    /// (public API above private helpers), else at the end of the body.
    BeforeHelpers,
    /// `Merge.after_def(name, arity)` — after the last clause of that
    /// function (keeps clause groups together), else at the end of the body.
    AfterDef { name: String, arity: usize },
    /// `Merge.describe()` — after the last top-level `describe`, else before
    /// the private helpers, else at the end of the body (test files keep
    /// describe blocks together).
    AfterDescribe,
    /// `Merge.after_directives()` — the start of the code region, after all
    /// directives; the home for DSL clusters (Vex `validates` lines) that
    /// must sit below the aliases they reference.
    AfterDirectives,
    /// `Merge.after_macro(macro, pred, fallback)` — after the last top-level
    /// local call to `macro_name` whose rendered first argument satisfies
    /// `predicate`; the `fallback` placement decides when nothing matches.
    /// Keeps DSL clusters grouped (`dispatch` under `dispatch`).
    AfterMacro {
        macro_name: String,
        predicate: MacroPredicate,
        fallback: Box<Placement>,
    },
    /// `Merge.after_macro_kw(macro, key, pred, fallback)` — same, matching
    /// the rendered value of keyword argument `key` (absent never matches).
    AfterMacroKw {
        macro_name: String,
        key: String,
        predicate: MacroPredicate,
        fallback: Box<Placement>,
    },
    /// `Merge.children_list()` — append the unit text as the last element of
    /// the `children = [...]` list at any depth; blocked when that assignment
    /// or its list does not exist.
    ChildrenList,
    /// `Merge.scope(chain)` — append the unit inside the deepest existing
    /// scope of the router's chain, materializing the missing tail as nested
    /// `scope` blocks; blocked when even the outermost scope is absent.
    Scope { chain: Vec<ScopeLevel> },
}

/// One level of the web router's scope chain — `Merge.scope/1`'s
/// `{path, alias}`, where a `None` alias renders the bare `scope "path"`.
pub type ScopeLevel = (String, Option<String>);

/// `Merge.build_route/2` — the missing tail of the chain wrapped around the
/// route line as plain text, so the route's own style survives the splice.
fn build_scope_route(chain: &[ScopeLevel], text: &str) -> String {
    let mut wrapped = text.to_string();
    for (path, alias) in chain.iter().rev() {
        wrapped = match alias {
            Some(module) => format!("scope \"{path}\", {module} do\n{wrapped}\nend"),
            None => format!("scope \"{path}\" do\n{wrapped}\nend"),
        };
    }
    wrapped
}

/// The argument test of `Merge.after_macro/3` and `Merge.after_macro_kw/4` —
/// every predicate the ported blueprints build is `fn _ -> true` or
/// `fn value -> value == expected`.
#[derive(Clone)]
pub enum MacroPredicate {
    Any,
    Eq(String),
}

impl Placement {
    /// The insert offset plus the exact chunk to splice, or `None` when
    /// blocked. The wrapper path of `Inside` materializes the container at
    /// the directive boundary — the block exists exactly when it has
    /// content, and never as an empty block.
    pub fn locate(&self, file: &ElixirFile, unit_text: &str) -> Option<(usize, String)> {
        match self {
            Placement::Head {
                rank,
                alias_sort_key,
            } => {
                let offset = file.insert_offset_head(*rank, alias_sort_key.as_deref())?;
                Some((offset, format!("{unit_text}\n")))
            }
            Placement::Inside {
                macro_name,
                wrapper,
                before_trailing,
            } => {
                if let Some(offset) =
                    file.insert_offset_inside(macro_name, before_trailing.as_deref())
                {
                    return Some((offset, format!("{unit_text}\n")));
                }
                let container = wrapper.as_ref()?;
                let offset = file.insert_offset_after_directives()?;
                Some((
                    offset,
                    format!("{}\n", container.replace("{unit}", unit_text)),
                ))
            }
            Placement::BodyEnd => {
                let offset = file.insert_offset_body_end()?;
                Some((offset, format!("{unit_text}\n")))
            }
            Placement::BeforeHelpers => {
                let offset = file.insert_offset_before_helpers()?;
                Some((offset, format!("{unit_text}\n")))
            }
            Placement::AfterDef { name, arity } => {
                let offset = file.insert_offset_after_def(name, *arity)?;
                Some((offset, format!("{unit_text}\n")))
            }
            Placement::AfterDescribe => {
                let offset = file.insert_offset_after_describe()?;
                Some((offset, format!("{unit_text}\n")))
            }
            Placement::AfterDirectives => {
                let offset = file.insert_offset_after_directives()?;
                Some((offset, format!("{unit_text}\n")))
            }
            Placement::AfterMacro {
                macro_name,
                predicate,
                fallback,
            } => match file.insert_offset_after_macro(macro_name, predicate) {
                Some(offset) => Some((offset, format!("{unit_text}\n"))),
                None => fallback.locate(file, unit_text),
            },
            Placement::AfterMacroKw {
                macro_name,
                key,
                predicate,
                fallback,
            } => match file.insert_offset_after_macro_kw(macro_name, key, predicate) {
                Some(offset) => Some((offset, format!("{unit_text}\n"))),
                None => fallback.locate(file, unit_text),
            },
            Placement::ChildrenList => None,
            Placement::Scope { chain } => {
                let (offset, depth) = file.insert_offset_scope(chain)?;
                let route = build_scope_route(&chain[depth..], unit_text);
                Some((offset, format!("{route}\n")))
            }
        }
    }

    /// The full text of the file after this placement, or `None` when blocked.
    /// Every placement but `ChildrenList` is a pure insert at `locate`'s
    /// offset; `Merge.children_list/0` rebuilds the whole `children = [...]`
    /// node, so its port replaces that node's bytes (collapsing a multi-line
    /// source list to the reprint's single line).
    pub fn apply(&self, file: &ElixirFile, unit_text: &str) -> Option<String> {
        if let Placement::ChildrenList = self {
            return file.children_list_replace(unit_text);
        }
        let (offset, chunk) = self.locate(file, unit_text)?;
        Some(file.splice(offset, &chunk))
    }
}

/// One insertable chunk — `SpGen.Unit`. Gates and the stale details are
/// data resolved at plan time (`requires.(ctx)` and `stale.(source, ctx)`
/// in Elixir terms; plans are per-context, so the answers are constants).
/// A presence question about the target file — `Unit.check`.
type CheckFn = dyn Fn(&ElixirFile) -> bool;
/// The unit's rendered source — `Unit.render`.
type RenderFn = dyn Fn() -> String;
/// Present-but-incomplete details for an existing line (the `Outdated`
/// report); never appended.
pub type StaleFn = dyn Fn(&ElixirFile) -> Vec<String>;
/// The stale check a unit carries, boxed: `None` for a unit with nothing to
/// compare, so a blueprint that builds its notice in a closure can name the
/// type it hands the plan.
pub type Stale = Option<Box<StaleFn>>;

pub struct Unit {
    pub id: UnitId,
    pub check: Box<CheckFn>,
    pub render: Box<RenderFn>,
    pub place: Placement,
    /// `[{path, reason}]` that must exist before this unit may place.
    pub requires: Vec<(String, String)>,
    pub stale: Stale,
}

pub struct FilePlan {
    pub path: String,
    pub module: Option<String>,
    pub units: Vec<Unit>,
    /// Whole-file creation text (scaffold blueprints); `None` when the file
    /// is unit-created or a registration host.
    pub scaffold: Option<String>,
    pub format: bool,
    pub unit_created: bool,
    /// Test files appear with their first landing `describe`.
    pub requires_describe: bool,
    /// Model-owned whole-file rewrite (`Fixtures`/`Factory` projections).
    pub projection: bool,
    /// The file-level gate of a projection.
    pub gate: Vec<(String, String)>,
}

impl FilePlan {
    /// The minimal builder a blueprint uses; the optional fields start at
    /// the Elixir defaults.
    pub fn new(path: String, module: Option<String>, units: Vec<Unit>) -> Self {
        FilePlan {
            path,
            module,
            units,
            scaffold: None,
            format: true,
            unit_created: true,
            requires_describe: false,
            projection: false,
            gate: Vec::new(),
        }
    }
}

/// The generator a blueprint drives, as declared by the primary blueprint.
pub trait Blueprint {
    /// `SpGen.Blueprint.name/0`
    fn name(&self) -> &'static str;
    fn description(&self) -> Option<&'static str> {
        None
    }
    /// `SpGen.Blueprint.source_kinds/0` — the element kinds accepted.
    fn source_kinds(&self) -> Vec<spgen_model::ElementKind>;
    /// `SpGen.Blueprint.actor/0`
    fn actor(&self) -> Actor {
        Actor::Domain
    }
    /// `SpGen.Blueprint.closure_scope/0`
    fn closure_scope(&self) -> ClosureScope {
        ClosureScope::All
    }
    /// `SpGen.Blueprint.operations/0` — a fixed blueprint renders one
    /// shape; template-driven blueprints override this and `operations`.
    fn is_fixed(&self) -> bool {
        true
    }
    fn operations(&self) -> Vec<crate::context::Operation> {
        Vec::new()
    }
    /// `SpGen.Blueprint.optional_template?/0`
    fn optional_template(&self) -> bool {
        false
    }
    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        Vec::new()
    }
    /// `SpGen.Blueprint.plans/1`
    fn plans(&self, ctx: &Context) -> Vec<FilePlan>;
    /// `SpGen.Blueprint.dependencies/1` — blueprints whose code this
    /// blueprint's output calls, planned before it in the same run.
    fn dependencies(&self, _ctx: &Context) -> Vec<Dependency> {
        Vec::new()
    }
    /// The optional model-content gate — `SpGen.Blueprint.validate/1`,
    /// reached through `Blueprint.validate_hook/2`: a blueprint may verify
    /// the model carries what its code needs before anything is planned or
    /// written; `Ok(())` continues, `Err(messages)` aborts the run with
    /// every message. A generator never writes code from a model that
    /// violates its contract. The oracle answers
    /// `function_exported?(blueprint, :validate, 1)` — the port's default
    /// `Ok(())` is the unexported case.
    fn validate(&self, _ctx: &Context) -> Result<(), Vec<String>> {
        Ok(())
    }
}

#[derive(PartialEq, Eq)]
pub enum Actor {
    Domain,
    Web,
}

#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ClosureScope {
    All,
    None,
}

/// A planned dependency: which blueprint, driven from which element.
pub struct Dependency {
    pub blueprint_name: &'static str,
    pub element: spgen_model::Element,
}
