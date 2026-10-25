defmodule Sportipedia.Codegen.Context do
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
  * data: fields (canonical order), validators (from aggregate invariants and
    command constraints), published events, actors, documentation prose

  Renders blueprint templates with the placeholder engine.
  """

  alias Sportipedia.Codegen.{Esdm, Placeholders}
  alias Sportipedia.Codegen.Esdm.Element

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
    :events,
    :actors,
    :scenarios,
    :repo_root
  ]

  @type operation :: :create | :update | :delete | :read | :collection
  @type effect :: :create | :update | :delete

  @operations ~w(create update delete read collection)a

  @doc "The five operations a template-driven blueprint can render."
  def operations, do: @operations

  @doc """
  Builds the context for `element`.

  Options: `:subdomain`, `:composite`, `:constituent` (overrides), `:operation`
  (defaults to `:create`).
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
        operation: Keyword.get(opts, :operation, :create),
        repo_root: Keyword.get(opts, :repo_root),
        aggregate: fetch(Esdm.aggregate_of(model, element)),
        read_model: fetch(Esdm.read_model_for(model, element)),
        events:
          Esdm.publishes(element) |> Enum.map(&find_event(model, &1)) |> Enum.reject(&is_nil/1),
        actors: Esdm.actors(element),
        scenarios: Esdm.scenarios(model, element)
      }

      fields = fields_for(ctx)

      {:ok, %{ctx | fields: fields, validators: validators_for(ctx, fields)}}
    end
  end

  # {:error, {:unknown_location, var}} when neither inferred nor provided
  defp location(var, opts, inferred) do
    case Keyword.get(opts, var) || inferred do
      nil -> {:error, {:unknown_location, var}}
      value -> {:ok, value}
    end
  end

  defp fetch({:ok, e}), do: e
  defp fetch(_error), do: nil

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

  # validators from aggregate invariants + command constraints, matched
  # against the context's fields (which already carry the injected id)
  defp validators_for(%__MODULE__{} = ctx, fields) do
    invs = if ctx.aggregate, do: Esdm.invariants(ctx.aggregate), else: []
    cons = Esdm.constraints(ctx.element)
    field_names = Enum.map(fields, & &1.name)

    (invs ++ cons)
    |> Enum.map(&validator_for(&1, field_names))
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.name)
  end

  defp validator_for(%{"name" => name} = rule, field_names) do
    text = "#{name} #{rule["rule"]}"
    field = Enum.find(field_names, fn f -> text =~ ~r/\b#{Regex.escape(f)}\b/i end)

    if field do
      kind = if name =~ ~r/unique/i, do: :unique, else: :exists

      %{
        name: name,
        field: field,
        kind: kind,
        module: pascal(name),
        snake: String.replace(name, "-", "_")
      }
    end
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
