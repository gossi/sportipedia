defmodule SpGen.Context do
  @moduledoc """
  Resolves everything a blueprint needs from one ESDM element plus CLI args.

  * identity: the element's `esdm:` address, kind, name
  * architecture location: `subdomain`, `composite`, `constituent` — inferred
    (subdomain/composite from the model file's position under
    `docs/domain-model/`, constituent from `scope.aggregate`, a query's
    `readModel`, or the element's own name), overridable via args, hard error
    when unknown
  * `operation`: the `:create | :update | :delete | :read | :collection`
    template the user selected with `--template`
  * data: fields (canonical order), validators (the invariant/constraint rules
    `SpGen.Invariant` resolved to a pattern), unresolved rules (named by the
    model, claimed by no pattern), published events, actors, documentation
    prose

  Renders blueprint templates with the placeholder engine.
  """

  alias SpGen.{Esdm, Invariant, Placeholders}
  alias SpGen.Esdm.Element

  @enforce_keys [:element, :model, :subdomain, :composite, :constituent, :operation]
  defstruct [
    :element,
    :model,
    :subdomain,
    :composite,
    :constituent,
    :operation,
    :aggregate,
    :read_model,
    :fields,
    :validators,
    :unresolved,
    :events,
    :actors,
    :scenarios,
    :repo_root,
    fs: SpGen.FS.default()
  ]

  @type operation :: :create | :update | :delete | :read | :collection
  @type effect :: :create | :update | :delete

  @operations ~w(create update delete read collection)a

  @doc "The five operations a template-driven blueprint can render."
  def operations, do: @operations

  @doc """
  Builds the context for `element`.

  Options: `:subdomain`, `:composite`, `:constituent` (overrides), `:operation`
  (defaults to the operation derived from the domain model — see
  `derive_operation/2`).
  """
  @spec build(Esdm.t(), Element.t(), keyword()) :: {:ok, %__MODULE__{}} | {:error, term()}
  def build(model, element, opts \\ []) do
    with {:ok, subdomain} <- location(:subdomain, opts, infer_subdomain(element)),
         {:ok, composite} <- location(:composite, opts, infer_composite(element)),
         {:ok, constituent} <- location(:constituent, opts, infer_constituent(model, element)) do
      ctx = %__MODULE__{
        element: element,
        model: model,
        subdomain: subdomain,
        composite: composite,
        constituent: constituent,
        operation: Keyword.get(opts, :operation) || derive_operation(model, element),
        repo_root: Keyword.get(opts, :repo_root),
        fs: Keyword.get(opts, :fs, SpGen.FS.default()),
        aggregate: fetch(aggregate_link(model, element)),
        read_model: fetch(read_model_link(model, element)),
        events:
          Esdm.publishes(element) |> Enum.map(&find_event(model, &1)) |> Enum.reject(&is_nil/1),
        actors: Esdm.actors(element),
        scenarios: Esdm.scenarios(model, element)
      }

      fields = fields_for(ctx)
      {validators, unresolved} = validators_for(ctx, fields)

      {:ok, %{ctx | fields: fields, validators: validators, unresolved: unresolved}}
    end
  end

  # {:error, {:unknown_location, var}} when neither inferred nor provided
  defp location(var, opts, inferred) do
    case Keyword.get(opts, var) || inferred do
      nil -> {:error, {:unknown_location, var}}
      value -> {:ok, value}
    end
  end

  # What the element's operation does, read from the model:
  #
  # * command/event — the effect of the published event's projection rule on
  #   the read model (`create` inserts a row, `update` merges, `delete`
  #   removes it)
  # * query — `:collection` when the result is an array, `:read` otherwise
  # * anything else — `:create` (the template is irrelevant or fixed)
  @doc false
  @spec derive_operation(Esdm.t(), Element.t()) :: __MODULE__.operation()
  def derive_operation(model, %Element{} = element) do
    case element.kind do
      :command ->
        # a command's own verb states what it does to the aggregate; the
        # projection rule only describes the effect on the read model
        verb_operation(element.name) ||
          element |> Esdm.publishes() |> List.first() |> event_effect(model, element)

      :event ->
        event_effect(element.name, model, element)

      :query ->
        if get_in(element.doc, ["result", "type"]) == "array", do: :collection, else: :read

      _kind ->
        :create
    end
  end

  defp event_effect(nil, _model, _element), do: :create

  defp event_effect(event_name, model, element) do
    with {:ok, rm} <- Esdm.read_model_for(model, element) do
      case Enum.find(Esdm.projections(rm), fn p -> p["event"] == event_name end) do
        nil -> :create
        projection -> Esdm.projection_effect(projection)
      end
    else
      _ -> :create
    end
  end

  defp fetch({:ok, e}), do: e
  defp fetch(_error), do: nil

  # a generator may be driven from the aggregate/read-model element itself
  # (e.g. `sp.gen.internal_api position`); the aggregate_of/read_model_for
  # lookups only follow links from related elements, so self-link here
  defp aggregate_link(model, %Element{kind: :aggregate} = element),
    do: model |> Esdm.aggregate_of(element) |> or_self(element, :aggregate)

  # read models project from exactly one aggregate (their first projection);
  # self-linking it gives read-model-driven generators the aggregate's rules
  # (invariants + command constraints), e.g. unique fields for the read model
  defp aggregate_link(model, %Element{kind: :"read-model"} = element) do
    case Esdm.projections(element) do
      [%{"aggregate" => name} | _] -> Esdm.find(model, :aggregate, name)
      _ -> {:error, :not_found}
    end
  end

  defp aggregate_link(model, element), do: Esdm.aggregate_of(model, element)

  defp read_model_link(model, %Element{kind: :"read-model"} = element),
    do: model |> Esdm.read_model_for(element) |> or_self(element, :"read-model")

  defp read_model_link(model, element), do: Esdm.read_model_for(model, element)

  defp or_self({:error, _}, %Element{kind: kind} = e, kind), do: {:ok, e}
  defp or_self(other, _e, _kind), do: other

  # -- inference ------------------------------------------------------------

  # docs/domain-model/<subdomain>/<composite>/.../<file>.esdm.yaml — the repo
  # layout is the architecture's source for subdomain and composite; the file
  # itself is not a directory segment
  defp model_dir_segments(element) do
    parts = element.source |> Path.dirname() |> Path.split()
    idx = Enum.find_index(parts, &(&1 == "domain-model"))

    if idx, do: Enum.slice(parts, (idx + 1)..-1//1), else: []
  end

  defp infer_subdomain(element) do
    case model_dir_segments(element) do
      [sub | _] -> sub
      [] -> nil
    end
  end

  defp infer_composite(element) do
    case model_dir_segments(element) do
      [_sub, comp | _rest] -> comp
      _ -> nil
    end
  end

  defp infer_constituent(_model, element) do
    case element.kind do
      :aggregate ->
        element.name

      kind when kind in [:command, :event, :feature] ->
        Element.aggregate_name(element)

      :query ->
        Element.read_model_name(element)

      kind when kind in [:"read-model", :entity, :"value-object"] ->
        element.name

      _ ->
        nil
    end
  end

  # -- data ------------------------------------------------------------------

  defp fields_for(%__MODULE__{element: element} = ctx) do
    base = Esdm.fields(element)

    with_id =
      case ctx.operation do
        # create: the public API generates the id — carried by the command,
        # but not provided by the caller, hence internal
        :create -> with_id(base, ctx, true)
        # update/delete address an existing object — the caller provides the id
        op when op in [:update, :delete] -> with_id(base, ctx, false)
        _ -> base
      end

    Enum.map(with_id, fn f -> Map.put_new(f, :internal, false) end)
  end

  defp with_id(fields, ctx, internal?) do
    if Enum.any?(fields, &(&1.name == "id")) do
      fields
    else
      id = generated_id(ctx) |> Enum.map(&Map.put(&1, :internal, internal?))
      id ++ fields
    end
  end

  defp generated_id(%__MODULE__{aggregate: %{doc: doc}}) when is_map(doc) do
    format = if get_in(doc, ["identifiedBy", "generator"]) == "uuid", do: "uuid", else: nil

    [
      %{
        name: "id",
        type: "string",
        format: format,
        description: "Unique identifier",
        required: true
      }
    ]
  end

  defp generated_id(_), do: []

  defp find_event(model, name) do
    case Esdm.find(model, :event, name) do
      {:ok, e} -> e
      _ -> nil
    end
  end

  # the citizen's invariant/constraint rules, resolved by the pattern registry
  # against the context's fields (which already carry the injected id)
  defp validators_for(%__MODULE__{} = ctx, fields) do
    invs = if ctx.aggregate, do: Esdm.invariants(ctx.aggregate), else: []
    cons = Enum.flat_map(constraint_sources(ctx), &Esdm.constraints/1)
    field_names = Enum.map(fields, & &1.name)

    {validators, unresolved} =
      (invs ++ cons)
      |> Enum.uniq_by(& &1["name"])
      |> Invariant.resolve_all(field_names, ctx.constituent)

    {Enum.sort_by(validators, & &1.name), Enum.sort_by(unresolved, & &1["name"])}
  end

  # Constraint rules live on the commands; when the generator is driven from
  # the aggregate itself (bare-name resolution), the aggregate's commands'
  # rules are the same citizen's constraints
  defp constraint_sources(%__MODULE__{element: %Element{kind: :aggregate} = aggregate} = ctx) do
    [aggregate | commands_of(ctx.model, aggregate.name)]
  end

  defp constraint_sources(%__MODULE__{element: element}), do: [element]

  defp commands_of(%Esdm{} = model, aggregate) do
    Enum.filter(model.elements, fn
      %Element{kind: :command} = e -> Element.aggregate_name(e) == aggregate
      _ -> false
    end)
  end

  @doc """
  Fields carrying a unique rule (aggregate invariants + command constraints),
  e.g. the slug of a `unique-slug` invariant.
  """
  @spec unique_fields(%__MODULE__{}) :: [String.t()]
  def unique_fields(%__MODULE__{} = ctx) do
    ctx.validators
    |> Enum.filter(&(&1.kind == :unique))
    |> Enum.map(& &1.field)
  end

  @doc """
  Commands of the same aggregate that publish this event, sorted by name —
  the deterministic lookup that places an event's tests in the operation test
  file of the command that produces it.
  """
  @spec publishing_commands(%__MODULE__{}) :: [Element.t()]
  def publishing_commands(%__MODULE__{element: %{kind: :event, name: name}, model: model}) do
    model.elements
    |> Enum.filter(fn e ->
      e.kind == :command and Esdm.publishes(e) |> Enum.member?(name)
    end)
    |> Enum.sort_by(& &1.name)
  end

  def publishing_commands(_ctx), do: []

  @doc "Placeholder variables for this context (canonical variable names as strings)."
  @spec vars(%__MODULE__{}) :: map()
  def vars(%__MODULE__{} = ctx) do
    %{
      "subdomain" => ctx.subdomain,
      "composite" => ctx.composite,
      "constituent" => ctx.constituent,
      "domain_object" => ctx.constituent,
      "public_api" => ctx.constituent,
      "operation" => ctx.element.name,
      "action" => ctx.element.name,
      "command" => command_name(ctx),
      "event" => event_name(ctx),
      "query" => query_name(ctx),
      "entity" => ctx.constituent,
      "value_object" => ctx.constituent,
      "object" => ctx.constituent,
      "jsonapi_type" => ctx.constituent,
      "field" => nil
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp command_name(%{element: %{kind: :command} = e}), do: e.name
  defp command_name(%{aggregate: _}), do: nil

  defp event_name(%{element: %{kind: :event} = e}), do: e.name

  defp event_name(%{events: [first | _]} = ctx) do
    if first, do: first.name, else: fallback_event(ctx)
  end

  defp event_name(_), do: nil

  defp fallback_event(_ctx), do: nil

  defp query_name(%{element: %{kind: :query} = e}), do: e.name
  defp query_name(_), do: nil

  @doc """
  Prose slots filled from the domain model or from stable TODO markers.

  Generators never invent vocabulary: when the ESDM document has no
  description, the marker `TODO: <the slot asks>` keeps the blueprint's own
  wording and is stable across runs (present units are skipped).
  """
  @spec slots(%__MODULE__{}) :: map()
  def slots(%__MODULE__{} = ctx) do
    desc = Esdm.describe(ctx.element)

    base = %{
      "Describe what the command does to the aggregate, derived from the domain model." =>
        doc_text(desc, "describe what the command does to the aggregate"),
      "Describe what happened in the domain, derived from the event name." =>
        doc_text(desc, "describe what happened in the domain"),
      "bounded_context" => bounded_context(ctx),
      "describe the operation" => doc_text(desc, "describe the #{ctx.element.name} operation"),
      "describe the params" => "The #{ctx.constituent} attributes",
      "describe the result" => "The #{ctx.constituent}",
      "describe the domain object" => ctx.constituent
    }

    Map.merge(field_type_slots(ctx), base)
  end

  defp doc_text(nil, instruction), do: "TODO: #{instruction}"
  defp doc_text("", instruction), do: "TODO: #{instruction}"
  defp doc_text(desc, _instruction) when is_binary(desc), do: desc

  # "<field type>" and the per-field type slots for every field name
  defp field_type_slots(%__MODULE__{} = ctx) do
    ctx.fields
    |> Enum.reduce(%{"field type" => "String.t()"}, fn f, acc ->
      Map.put(acc, "#{f.name} type", elixir_type(f))
    end)
  end

  @doc "Elixir type for a typedstruct field."
  def elixir_type(%{type: "string"}), do: "String.t()"
  def elixir_type(%{type: "integer"}), do: "integer()"
  def elixir_type(%{type: "number"}), do: "float()"
  def elixir_type(%{type: "boolean"}), do: "boolean()"
  def elixir_type(%{type: "object"}), do: "map()"
  def elixir_type(%{type: "array"}), do: "[term()]"
  def elixir_type(_), do: "String.t()"

  @doc "Ecto type atom text for schema fields (read models, P3)."
  def ecto_type(%{type: "string", format: "uuid"}), do: ":binary_id"
  def ecto_type(%{type: "string", format: "date-time"}), do: ":utc_datetime_usec"
  def ecto_type(%{type: "string"}), do: ":string"
  def ecto_type(%{type: "integer"}), do: ":integer"
  def ecto_type(%{type: "number"}), do: ":float"
  def ecto_type(%{type: "boolean"}), do: ":boolean"
  def ecto_type(%{type: "object"}), do: ":map"
  def ecto_type(%{type: "array"}), do: {:array, :string}
  def ecto_type(_), do: ":string"

  @doc """
  Renders a blueprint template: placeholders from `vars` (+ overrides),
  prose from `slots` (+ overrides). Raises on unresolvable placeholders.
  """
  @spec render(String.t(), %__MODULE__{}, map(), map()) :: String.t()
  def render(template, %__MODULE__{} = ctx, extra_vars \\ %{}, extra_slots \\ %{}) do
    Placeholders.render(template, %{
      vars: Map.merge(vars(ctx), extra_vars),
      slots: Map.merge(slots(ctx), extra_slots)
    })
  end

  @doc "Rendered module name for a dotted template."
  def render_module(template, ctx, extra_vars \\ %{}), do: render(template, ctx, extra_vars)

  # -- derived facts for the constituent/web blueprints -----------------------

  @doc "The snake_case operation key (`catalog_apparatus`)."
  def op_snake(%__MODULE__{} = ctx), do: ctx.element.name |> String.replace("-", "_")

  @doc "The `esdm:` scope's bounded context, for prose."
  def bounded_context(%__MODULE__{element: %{scope: scope}}) do
    case List.keyfind(scope, "bounded-context", 0) do
      {_, name} -> name
      nil -> "the catalog"
    end
  end

  @doc "All events owned by the context's aggregate, sorted by name."
  def aggregate_events(%__MODULE__{model: model, aggregate: %{name: name}}) when not is_nil(name),
    do: Esdm.events_of(model, name)

  def aggregate_events(%__MODULE__{model: model, element: element}) do
    case Element.aggregate_name(element) do
      nil -> []
      name -> Esdm.events_of(model, name)
    end
  end

  @doc """
  The operation an event performs on the read model (via its projection rule):
  `:create` | `:update` | `:delete`, defaulting to `:create`.
  """
  def effect_for_event(%__MODULE__{read_model: rm}, event_name) when not is_nil(rm) do
    rm
    |> Esdm.projections()
    |> Enum.find(&(&1["event"] == event_name))
    |> case do
      nil -> :create
      projection -> Esdm.projection_effect(projection)
    end
  end

  def effect_for_event(_ctx, _event_name), do: :create

  # `archive-position`, `edit-position`, `catalog-position`: the leading verb
  # of the command's name is what it does to the aggregate
  defp verb_operation(name) do
    cond do
      name =~ ~r/\A(archive|delete|remove|withdraw)(-|\z)/ -> :delete
      name =~ ~r/\A(edit|update|amend|change)(-|\z)/ -> :update
      name =~ ~r/\A(catalog|create|add|register)(-|\z)/ -> :create
      true -> nil
    end
  end

  @doc "Parameter names of a query's `parameters.oneOf`, e.g. [\"id\", \"slug\"]."
  def one_of_params(%__MODULE__{element: %{doc: doc}}) do
    doc
    |> get_in(["parameters", "oneOf"])
    |> List.wrap()
    |> Enum.flat_map(fn branch -> (branch["properties"] || %{}) |> Map.keys() end)
    |> Enum.uniq()
  end

  def one_of_params(_ctx), do: []

  @doc "The path parameter name for a read query (`id`, `id_or_slug`, …)."
  def read_param(%__MODULE__{} = ctx) do
    case one_of_params(ctx) do
      [] -> "id"
      names -> Enum.join(names, "_or_")
    end
  end

  @doc "A query's `parameters.properties` (collection queries), as a map or %{}."
  def query_parameters(%__MODULE__{element: %{doc: doc}}) do
    get_in(doc, ["parameters", "properties"]) || %{}
  end

  def query_parameters(_ctx), do: %{}

  @doc "Read-model fields rendered for schema/view purposes (ecto-typed)."
  def read_model_fields(%__MODULE__{read_model: rm}) when not is_nil(rm), do: Esdm.fields(rm)
  def read_model_fields(_ctx), do: []

  @doc "True for queries returning a collection (`result.type: array`)."
  def collection?(%__MODULE__{element: %{kind: :query, doc: doc}}) do
    get_in(doc, ["result", "type"]) == "array"
  end

  def collection?(_ctx), do: false

  @doc "The module-name Pascal form of a kebab name (PublicAPI, ReadModel, …)."
  def pascal(name) do
    name |> String.split("-") |> Enum.map(&String.capitalize/1) |> Enum.join()
  end
end
