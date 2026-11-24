use sparch_model::ElementKind;

use crate::blueprints::command::Command;
use crate::blueprints::internal_api::InternalApi;
use crate::blueprints::query::Query;
use crate::blueprints::read_model::ReadModel;
use crate::context::{Befield, Context, Operation};
use crate::elixir::{ElixirFile, Rank};
use crate::plan::{Blueprint, Dependency, FilePlan, Placement, Stale, Unit, UnitId};

const PATH: &str =
    "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/public_api.ex";
const MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>";
const READ_MODEL_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel";
const INTERNAL_MODULE: &str =
    "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal";
const COMMAND_MODULE: &str = "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>";
const APP_MODULE: &str = "Sportipedia.<Subdomain>";
const REPO_MODULE: &str = "Sportipedia.<Subdomain>.Repo";
const INLINE_BUILDER: &str = "QueryBuilder.build(";

pub struct PublicApi;

impl PublicApi {
    pub fn module_file(ctx: &Context) -> String {
        ctx.render_or_panic(PATH)
    }

    pub fn module_template() -> &'static str {
        MODULE
    }
}

impl Blueprint for PublicApi {
    fn name(&self) -> &'static str {
        "public_api"
    }

    fn description(&self) -> Option<&'static str> {
        Some("Generates the public API function for an operation")
    }

    fn source_kinds(&self) -> Vec<ElementKind> {
        vec![ElementKind::Command, ElementKind::Query]
    }

    fn is_fixed(&self) -> bool {
        false
    }

    fn operations(&self) -> Vec<Operation> {
        vec![
            Operation::Create,
            Operation::Update,
            Operation::Delete,
            Operation::None,
            Operation::Read,
            Operation::Collection,
        ]
    }

    fn optional_template(&self) -> bool {
        true
    }

    fn dependencies(&self, ctx: &Context) -> Vec<Dependency> {
        if ctx.element.kind == ElementKind::Query && ctx.collection() {
            vec![Dependency {
                blueprint_name: "query",
                element: ctx.element.clone(),
            }]
        } else {
            Vec::new()
        }
    }

    fn generated_files(&self) -> Vec<(&'static str, &'static str)> {
        vec![(PATH, "public function per operation")]
    }
    fn plans(&self, ctx: &Context) -> Vec<FilePlan> {
        match body(ctx) {
            Some(text) => vec![FilePlan::new(
                ctx.render_or_panic(PATH),
                Some(ctx.render_or_panic(MODULE)),
                units(ctx, &text),
            )],
            None => Vec::new(),
        }
    }
}

pub fn aliases(ctx: &Context) -> Vec<String> {
    let base = vec![
        "alias Sportipedia.Architecture".to_string(),
        format!("alias {}", ctx.render_or_panic(APP_MODULE)),
    ];
    let command_alias = || format!("alias {}", ctx.render_or_panic(COMMAND_MODULE));
    let internal_alias = || format!("alias {}", ctx.render_or_panic(INTERNAL_MODULE));
    let read_model_alias = || format!("alias {}", ctx.render_or_panic(READ_MODEL_MODULE));

    let lines = if ctx.element.kind == ElementKind::Command
        && matches!(
            ctx.operation,
            Some(Operation::Delete) | Some(Operation::None)
        ) {
        vec![
            command_alias(),
            "alias Sportipedia.Support.ErrorClassifier".to_string(),
        ]
    } else if ctx.element.kind == ElementKind::Command {
        vec![
            command_alias(),
            internal_alias(),
            "alias Sportipedia.Support.ErrorClassifier".to_string(),
            read_model_alias(),
        ]
    } else if ctx.collection() {
        vec![
            read_model_alias(),
            format!("alias {}", ctx.render_or_panic(REPO_MODULE)),
            format!("alias {}", ctx.render_or_panic(Query::module_template())),
        ]
    } else {
        let mut tail = vec![internal_alias(), read_model_alias()];
        if ctx.read_param().contains("_or_") {
            tail.push("alias Sportipedia.Support.Validators.UuidValidator".to_string());
        }
        tail
    };

    let mut out: Vec<String> = Vec::new();
    for line in base.into_iter().chain(lines) {
        if !out.contains(&line) {
            out.push(line);
        }
    }
    out
}

pub fn body(ctx: &Context) -> Option<String> {
    let op = ctx.op_snake();
    let doc = doc_prose(ctx);

    match ctx.element.kind {
        ElementKind::Command => match ctx.operation {
            Some(Operation::Create) => Some(create(ctx, &op, &doc)),
            Some(Operation::Update) => Some(update(ctx, &op, &doc)),
            Some(Operation::Delete) => Some(delete(ctx, &op, &doc)),
            Some(Operation::None) => Some(none(ctx, &op, &doc)),
            _ => None,
        },
        _ => {
            if ctx.collection() {
                Some(collection(ctx, &op, &doc))
            } else {
                Some(read(ctx, &op, &doc))
            }
        }
    }
}

fn doc_prose(ctx: &Context) -> String {
    match ctx.element.doc.get("description").and_then(|d| d.as_str()) {
        Some(text) => text.to_string(),
        None => format!("TODO: describe {}", ctx.element.name),
    }
}

fn app(ctx: &Context) -> String {
    Context::pascal(&ctx.subdomain)
}

fn internal(ctx: &Context) -> String {
    format!("{}Internal", Context::pascal(&ctx.constituent))
}

fn read_model(ctx: &Context) -> String {
    format!("{}ReadModel", Context::pascal(&ctx.constituent))
}

fn command(ctx: &Context) -> String {
    Context::pascal(&ctx.element.name)
}

fn query_module(ctx: &Context) -> String {
    ctx.render_or_panic(Query::module_template())
        .rsplit('.')
        .next()
        .unwrap_or_default()
        .to_string()
}

fn create(ctx: &Context, op: &str, doc: &str) -> String {
    format!(
        "@doc \"\"\"\n{doc}\n\"\"\"\n@spec {op}({}) :: Architecture.public_api({}.t())\ndef {op}(params) do\n  id = UUID.uuid4()\n  cmd = {}.new(Map.put(params, \"id\", id))\n\n  case {}.dispatch(cmd, consistency: :strong) do\n    :ok ->\n      {{:ok, {}.{}_by_id(id)}}\n\n    {{:error, errors}} ->\n      ErrorClassifier.classify_error(errors)\n  end\nend",
        spec_map(ctx, false),
        read_model(ctx),
        command(ctx),
        app(ctx),
        internal(ctx),
        ctx.constituent
    )
}

fn update(ctx: &Context, op: &str, doc: &str) -> String {
    format!(
        "@doc \"\"\"\n{doc}\n\"\"\"\n@spec {op}({}) :: Architecture.public_api({}.t())\ndef {op}(params) do\n  case {}.dispatch({}.new(params), consistency: :strong) do\n    :ok ->\n      {{:ok, {}.{}_by_id(params[:id] || params[\"id\"])}}\n\n    {{:error, errors}} ->\n      ErrorClassifier.classify_error(errors)\n  end\nend",
        spec_map(ctx, true),
        read_model(ctx),
        app(ctx),
        command(ctx),
        internal(ctx),
        ctx.constituent
    )
}

fn delete(ctx: &Context, op: &str, doc: &str) -> String {
    format!(
        "@doc \"\"\"\n{doc}\n\"\"\"\n@spec {op}(String.t()) :: Architecture.public_api()\ndef {op}(id) do\n  case {}.dispatch({}.new(id: id), consistency: :strong) do\n    :ok -> :ok\n    {{:error, errors}} -> ErrorClassifier.classify_error(errors)\n  end\nend",
        app(ctx),
        command(ctx)
    )
}

fn none(ctx: &Context, op: &str, doc: &str) -> String {
    format!(
        "@doc \"\"\"\n{doc}\n\"\"\"\n@spec {op}(map()) :: Architecture.public_api()\ndef {op}(params) do\n  case {}.dispatch({}.new(params), consistency: :strong) do\n    :ok -> :ok\n    {{:error, errors}} -> ErrorClassifier.classify_error(errors)\n  end\nend",
        app(ctx),
        command(ctx)
    )
}

fn read(ctx: &Context, op: &str, doc: &str) -> String {
    let param = ctx.read_param();
    let do_ = ctx.constituent.clone();
    let parts: Vec<String> = param.split("_or_").map(str::to_string).collect();

    if parts.len() == 2 {
        return format!(
            "@doc \"\"\"\n{doc}\n\"\"\"\n@spec {op}(String.t()) :: Architecture.public_api({rm}.t())\ndef {op}({param}) do\n  case lookup_{do_}({param}) do\n    nil -> {{:error, :not_found}}\n    read_model -> {{:ok, read_model}}\n  end\nend\n\ndefp lookup_{do_}({param}) do\n  if UuidValidator.valid_uuid?({param}) do\n    {internal}.{do_}_by_{first}({param})\n  else\n    {internal}.{do_}_by_{second}({param})\n  end\nend",
            rm = read_model(ctx),
            internal = internal(ctx),
            first = parts[0],
            second = parts[1],
        );
    }
    format!(
        "@doc \"\"\"\n{doc}\n\"\"\"\n@spec {op}(String.t()) :: Architecture.public_api({rm}.t())\ndef {op}({param}) do\n  case {internal}.{do_}_by_id({param}) do\n    nil -> {{:error, :not_found}}\n    read_model -> {{:ok, read_model}}\n  end\nend",
        rm = read_model(ctx),
        internal = internal(ctx),
    )
}

fn collection(ctx: &Context, op: &str, doc: &str) -> String {
    format!(
        "@doc \"\"\"\n{doc}\n\"\"\"\n@spec {op}(JSONAPI.Config.t()) :: Architecture.public_api([{}.t()])\ndef {op}(query) do\n  {{:ok, Repo.all({}.new(query))}}\nend",
        read_model(ctx),
        query_module(ctx)
    )
}

fn spec_map(ctx: &Context, include_id: bool) -> String {
    let parts: Vec<String> = ctx
        .fields
        .iter()
        .filter(|f| include_id || !f.internal)
        .map(|f: &Befield| {
            if f.required {
                format!("required(:{}) => String.t()", f.name)
            } else {
                format!("optional(:{}) => String.t() | nil", f.name)
            }
        })
        .collect();
    format!("%{{{}}}", parts.join(", "))
}

fn body_gate(ctx: &Context) -> Vec<(String, String)> {
    match ctx.element.kind {
        ElementKind::Command => {
            let mut gates = vec![(
                Command::module_file(ctx),
                "command not generated (sparch command)".to_string(),
            )];
            if !matches!(
                ctx.operation,
                Some(Operation::Delete) | Some(Operation::None)
            ) {
                gates.push((
                    InternalApi::module_file(ctx),
                    "internal API not generated (sparch internal_api)".to_string(),
                ));
            }
            gates
        }
        ElementKind::Query => {
            let read_model = (
                ReadModel::module_file(ctx),
                "read model not generated (sparch read_model)".to_string(),
            );
            if ctx.collection() {
                vec![
                    (
                        Query::module_file(ctx),
                        "query not generated (sparch query)".to_string(),
                    ),
                    read_model,
                ]
            } else {
                vec![
                    (
                        InternalApi::module_file(ctx),
                        "internal API not generated (sparch internal_api)".to_string(),
                    ),
                    read_model,
                ]
            }
        }
        _ => Vec::new(),
    }
}

fn units(ctx: &Context, text: &str) -> Vec<Unit> {
    let op = ctx.op_snake();

    let doc = format!(
        "@moduledoc \"\"\"\nPublic API for managing {}s in the {}.\n\"\"\"",
        ctx.constituent,
        ctx.bounded_context()
    );
    let moduledoc = Unit {
        id: UnitId::Moduledoc,
        check: Box::new(|f| f.has_moduledoc()),
        render: Box::new(move || doc.clone()),
        place: Placement::Head {
            rank: Rank::Moduledoc,
            alias_sort_key: None,
        },
        requires: Vec::new(),
        stale: None,
    };

    let function = def_unit(ctx, &op, text);
    let alias_units: Vec<Unit> = aliases(ctx)
        .into_iter()
        .map(|line| {
            let module = line["alias ".len()..].to_string();
            let check_module = module.clone();
            let check_def = op.clone();
            Unit {
                id: UnitId::Alias(module.clone()),
                check: Box::new(move |f| f.has_alias(&check_module) || f.has_def(&check_def, 1)),
                render: Box::new(move || line.clone()),
                place: Placement::Head {
                    rank: Rank::Alias,
                    alias_sort_key: Some(module),
                },
                requires: Vec::new(),
                stale: None,
            }
        })
        .collect();

    let mut units = vec![moduledoc];
    units.extend(alias_units);
    units.push(function);
    units
}

fn def_unit(ctx: &Context, op: &str, text: &str) -> Unit {
    let render = format!("\n{}", text.trim_end());
    let requires = body_gate(ctx);
    let check_def = op.to_string();
    let present_def = op.to_string();
    let collection = ctx.operation == Some(Operation::Collection);
    let notice = if collection {
        Some(stale_notice(ctx))
    } else {
        None
    };
    let stale: Stale = Some(Box::new(move |file: &ElixirFile| match &notice {
        Some(notice) if file.has_def(&check_def, 1) && inline_builder(file) => {
            vec![notice.clone()]
        }
        _ => Vec::new(),
    }));
    Unit {
        id: UnitId::Def(op.to_string(), 1),
        check: Box::new(move |f| f.has_def(&present_def, 1) && (!collection || !inline_builder(f))),
        render: Box::new(move || render.clone()),
        requires,
        place: Placement::BodyEnd,
        stale,
    }
}

fn inline_builder(file: &ElixirFile) -> bool {
    file.text().contains(INLINE_BUILDER)
}

fn stale_notice(ctx: &Context) -> String {
    format!(
        "{}/1 builds the query inline — the query citizen owns how a JSON:API config becomes a query: call Repo.all({}.new(query)) and alias that module",
        ctx.op_snake(),
        query_module(ctx)
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::ContextOptions;
    use sparch_model::Model;
    use std::path::PathBuf;

    fn ctx_for(name: &str) -> Context {
        let root = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../fixtures/domain-model");
        let model = Model::load(&root.canonicalize().expect("fixture corpus"));
        let element = model
            .resolve(name, &[ElementKind::Command, ElementKind::Query])
            .expect("fixture operation");
        Context::build(&model, &element, &ContextOptions::default()).expect("context builds")
    }

    fn units_for(name: &str) -> Vec<Unit> {
        PublicApi.plans(&ctx_for(name)).remove(0).units
    }

    fn unit<'a>(units: &'a [Unit], label: &str) -> &'a Unit {
        units
            .iter()
            .find(|u| u.id.label() == label)
            .unwrap_or_else(|| panic!("no unit {label}"))
    }

    fn render(units: &[Unit], label: &str) -> String {
        (unit(units, label).render)()
    }

    #[test]
    fn paths_and_modules_render_as_the_model_expects() {
        let ctx = ctx_for("create-widget");
        assert_eq!(
            PublicApi::module_file(&ctx),
            "services/api/lib/sportipedia/catalog/equipment/widget/public_api.ex"
        );
        let plan = &PublicApi.plans(&ctx)[0];
        assert_eq!(
            plan.module.as_deref(),
            Some("Sportipedia.Catalog.Equipment.Widget")
        );
        assert!(plan.unit_created);
    }

    #[test]
    fn the_function_lands_after_the_aliases_it_needs() {
        let labels: Vec<String> = units_for("create-widget")
            .iter()
            .map(|u| u.id.label())
            .collect();
        assert_eq!(
            labels,
            vec![
                "moduledoc",
                "alias Sportipedia.Architecture",
                "alias Sportipedia.Catalog",
                "alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget",
                "alias Sportipedia.Catalog.Equipment.Widget.WidgetInternal",
                "alias Sportipedia.Support.ErrorClassifier",
                "alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel",
                "create_widget/1",
            ]
        );
    }

    #[test]
    fn the_moduledoc_names_the_constituent_and_the_bounded_context() {
        let units = units_for("create-widget");
        assert_eq!(
            render(&units, "moduledoc"),
            "@moduledoc \"\"\"\nPublic API for managing widgets in the sport.\n\"\"\""
        );
    }

    #[test]
    fn the_create_shape_generates_the_id_and_reads_the_projection() {
        let units = units_for("create-widget");
        assert_eq!(
            render(&units, "create_widget/1"),
            "\n@doc \"\"\"\nCatalogs a new widget in the equipment catalog\n\"\"\"\n@spec create_widget(%{required(:title) => String.t(), required(:slug) => String.t(), optional(:coach_id) => String.t() | nil, optional(:description) => String.t() | nil, optional(:label) => String.t() | nil, optional(:team_id) => String.t() | nil}) :: Architecture.public_api(WidgetReadModel.t())\ndef create_widget(params) do\n  id = UUID.uuid4()\n  cmd = CreateWidget.new(Map.put(params, \"id\", id))\n\n  case Catalog.dispatch(cmd, consistency: :strong) do\n    :ok ->\n      {:ok, WidgetInternal.widget_by_id(id)}\n\n    {:error, errors} ->\n      ErrorClassifier.classify_error(errors)\n  end\nend"
        );
    }

    #[test]
    fn the_update_shape_addresses_the_given_id() {
        let edited = render(&units_for("edit-widget"), "edit_widget/1");
        assert!(
            edited.contains("WidgetInternal.widget_by_id(params[:id] || params[\"id\"])"),
            "{edited}"
        );
        assert!(
            edited.contains("@spec edit_widget(%{required(:id)"),
            "the provided id is in the spec map:\n{edited}"
        );
    }

    #[test]
    fn the_delete_shape_returns_the_dispatch_result() {
        assert_eq!(
            render(&units_for("archive-widget"), "archive_widget/1"),
            "\n@doc \"\"\"\nArchives a widget that is no longer used\n\"\"\"\n@spec archive_widget(String.t()) :: Architecture.public_api()\ndef archive_widget(id) do\n  case Catalog.dispatch(ArchiveWidget.new(id: id), consistency: :strong) do\n    :ok -> :ok\n    {:error, errors} -> ErrorClassifier.classify_error(errors)\n  end\nend"
        );
    }

    #[test]
    fn the_none_shape_looks_up_no_read_model() {
        let noted = render(&units_for("note-widget"), "note_widget/1");
        assert!(
            noted.contains("@spec note_widget(map()) :: Architecture.public_api()"),
            "{noted}"
        );
        assert!(noted.contains("NoteWidget.new(params)"), "{noted}");
        assert!(
            !noted.contains("ReadModel"),
            "nothing materializes:\n{noted}"
        );
    }

    #[test]
    fn the_collection_shape_names_the_query_citizen() {
        let units = units_for("list-widgets");
        assert_eq!(
            render(&units, "list_widgets/1"),
            "\n@doc \"\"\"\nList all widgets with filtering, sorting, and pagination\n\"\"\"\n@spec list_widgets(JSONAPI.Config.t()) :: Architecture.public_api([WidgetReadModel.t()])\ndef list_widgets(query) do\n  {:ok, Repo.all(ListWidgets.new(query))}\nend"
        );
        let labels: Vec<String> = units.iter().map(|u| u.id.label()).collect();
        assert!(
            labels.contains(&"alias Sportipedia.Catalog.Repo".to_string()),
            "{labels:?}"
        );
        assert!(
            labels.contains(
                &"alias Sportipedia.Catalog.Equipment.Widget.Queries.ListWidgets".to_string()
            ),
            "{labels:?}"
        );
    }

    #[test]
    fn the_collection_function_defers_to_the_query_and_read_model_citizens() {
        let units = units_for("list-widgets");
        assert_eq!(
            unit(&units, "list_widgets/1").requires,
            vec![
                (
                    "services/api/lib/sportipedia/catalog/equipment/widget/queries/list_widgets.ex"
                        .to_string(),
                    "query not generated (sparch query)".to_string(),
                ),
                (
                    "services/api/lib/sportipedia/catalog/equipment/widget/read_model.ex"
                        .to_string(),
                    "read model not generated (sparch read_model)".to_string(),
                ),
            ]
        );
    }

    #[test]
    fn the_read_shape_over_id_or_slug_branches_in_a_private_helper() {
        let units = units_for("read-widget");
        assert_eq!(
            render(&units, "read_widget/1"),
            "\n@doc \"\"\"\nRetrieve a single widget by its id or slug\n\"\"\"\n@spec read_widget(String.t()) :: Architecture.public_api(WidgetReadModel.t())\ndef read_widget(id_or_slug) do\n  case lookup_widget(id_or_slug) do\n    nil -> {:error, :not_found}\n    read_model -> {:ok, read_model}\n  end\nend\n\ndefp lookup_widget(id_or_slug) do\n  if UuidValidator.valid_uuid?(id_or_slug) do\n    WidgetInternal.widget_by_id(id_or_slug)\n  else\n    WidgetInternal.widget_by_slug(id_or_slug)\n  end\nend"
        );
        let labels: Vec<String> = units.iter().map(|u| u.id.label()).collect();
        assert!(
            labels.contains(&"alias Sportipedia.Support.Validators.UuidValidator".to_string()),
            "{labels:?}"
        );
    }

    #[test]
    fn a_delete_or_none_command_needs_no_internal_api_gate() {
        let archive = units_for("archive-widget");
        let gates: Vec<&str> = unit(&archive, "archive_widget/1")
            .requires
            .iter()
            .map(|(_, reason)| reason.as_str())
            .collect();
        assert_eq!(gates, vec!["command not generated (sparch command)"]);
        let create = units_for("create-widget");
        let gates: Vec<&str> = unit(&create, "create_widget/1")
            .requires
            .iter()
            .map(|(_, reason)| reason.as_str())
            .collect();
        assert_eq!(
            gates,
            vec![
                "command not generated (sparch command)",
                "internal API not generated (sparch internal_api)"
            ]
        );
    }

    #[test]
    fn an_inline_builder_collection_is_reported_and_never_appended() {
        let text = "defmodule Sportipedia.Catalog.Equipment.Widget do\n  def list_widgets(query) do\n    {:ok, Repo.all(QueryBuilder.build(query, WidgetReadModel))}\n  end\nend\n";
        let file = ElixirFile::parse(text);
        let units = units_for("list-widgets");
        let function = unit(&units, "list_widgets/1");
        assert!(
            !(function.check)(&file),
            "the inline shape is not the delivery"
        );
        assert_eq!(
            (function.stale.as_ref().expect("a stale check"))(&file),
            vec![
                "list_widgets/1 builds the query inline — the query citizen owns how a JSON:API config becomes a query: call Repo.all(ListWidgets.new(query)) and alias that module".to_string()
            ]
        );
        let done = ElixirFile::parse(
            "defmodule Sportipedia.Catalog.Equipment.Widget do\n  def list_widgets(query) do\n    {:ok, Repo.all(ListWidgets.new(query))}\n  end\nend\n",
        );
        assert!((function.check)(&done));
        assert!((function.stale.as_ref().expect("a stale check"))(&done).is_empty());
    }

    #[test]
    fn the_collection_function_pulls_the_query_as_a_dependency() {
        let deps = PublicApi.dependencies(&ctx_for("list-widgets"));
        assert_eq!(deps.len(), 1);
        assert_eq!(deps[0].blueprint_name, "query");
        assert_eq!(deps[0].element.name, "list-widgets");
        assert!(PublicApi.dependencies(&ctx_for("read-widget")).is_empty());
        assert!(PublicApi.dependencies(&ctx_for("create-widget")).is_empty());
    }

    #[test]
    fn the_alias_check_counts_the_function_as_presence() {
        let shell = ElixirFile::parse(
            "defmodule M do\n  def create_widget(params) do\n    :ok\n  end\nend\n",
        );
        let units = units_for("create-widget");
        for unit in units.iter().filter(|u| matches!(u.id, UnitId::Alias(_))) {
            assert!((unit.check)(&shell), "{}", unit.id.label());
        }
    }

    #[test]
    fn the_finished_module_is_fully_present() {
        let text = "defmodule Sportipedia.Catalog.Equipment.Widget do\n  @moduledoc \"\"\"\n  Public API for managing widgets in the sport.\n  \"\"\"\n  alias Sportipedia.Architecture\n  alias Sportipedia.Catalog\n  alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget\n  alias Sportipedia.Catalog.Equipment.Widget.WidgetInternal\n  alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel\n  alias Sportipedia.Support.ErrorClassifier\n\n  @doc \"\"\"\n  Catalogs a new widget in the equipment catalog\n  \"\"\"\n  @spec create_widget(%{required(:title) => String.t()}) :: Architecture.public_api(WidgetReadModel.t())\n  def create_widget(params) do\n    id = UUID.uuid4()\n    cmd = CreateWidget.new(Map.put(params, \"id\", id))\n\n    case Catalog.dispatch(cmd, consistency: :strong) do\n      :ok ->\n        {:ok, WidgetInternal.widget_by_id(id)}\n\n      {:error, errors} ->\n        ErrorClassifier.classify_error(errors)\n    end\n  end\nend\n";
        let file = ElixirFile::parse(text);
        for unit in &units_for("create-widget") {
            assert!((unit.check)(&file), "{} must read present", unit.id.label());
        }
    }
}
