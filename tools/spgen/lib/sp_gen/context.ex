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

  @type operation :: :create | :update | :delete | :read | :collection | :none | nil
  @type effect :: Esdm.effect() | nil

  @operations ~w(create update delete none read collection)a

  @doc "The operations a template-driven blueprint can render."
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

  # What the element's operation does — always *declared*, never guessed:
  #
  # * command — the document's `metadata.annotations."spgen.operation"`; `nil` when
  #   nobody declared one (`--template` overrides; a run without either is
  #   refused by `SpGen` — generation must not guess domain intent)
  # * event — the effect its read model declares via `spgen.operation.<event>`;
  #   `:none` is a decision (no materialization), `nil` is an open question
  # * query — `:collection` when the result is an array, `:read` otherwise
  # * anything else — `:create` (the template is irrelevant or fixed)
  @doc false
  @spec derive_operation(Esdm.t(), Element.t()) :: __MODULE__.operation() | nil
  def derive_operation(model, %Element{} = element) do
    case element.kind do
      :command ->
        Esdm.declared_operation(element)

      :event ->
        with {:ok, rm} <- Esdm.read_model_for(model, element) do
          declared_effect(rm, element.name)
        else
          _ -> nil
        end

      :query ->
        if get_in(element.doc, ["result", "type"]) == "array", do: :collection, else: :read

      _kind ->
        :create
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

    unresolved = Enum.reject(unresolved, &realizable_by_citizen?(&1, ctx, field_names))

    {Enum.sort_by(validators, & &1.name), Enum.sort_by(unresolved, & &1["name"])}
  end

  # A rule that names a field only *another* element of the citizen carries is
  # not a gap: `spgen command create-widget` realizes `at-most-one-owner`, so
  # reporting it under `archive-widget` (which carries only `id`) would be noise
  # about a run instead of a fact about the model. A rule that names no field
  # anywhere in the citizen is the real thing: nothing can ever generate it.
  defp realizable_by_citizen?(rule, %__MODULE__{} = ctx, field_names) do
    text = "#{rule["name"]} #{rule["rule"]}"

    ctx
    |> citizen_field_names(field_names)
    |> Enum.any?(fn field -> text =~ ~r/\b#{Regex.escape(field)}\b/i end)
  end

  defp citizen_field_names(%__MODULE__{} = ctx, own) do
    elements =
      [ctx.element, ctx.aggregate, ctx.read_model] ++
        case ctx.aggregate do
          %{name: name} -> commands_of(ctx.model, name)
          nil -> []
        end

    (own ++
       (elements
        |> Enum.reject(&is_nil/1)
        |> Enum.flat_map(&Esdm.fields/1)
        |> Enum.map(& &1.name)))
    |> Enum.uniq()
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
  The citizen's rules that no `SpGen.Invariant` pattern realizes, as
  `{name, rule_text}`, sorted by name.

  A rule naming no field of the citizen is not a validator — it is an
  operational precondition over another aggregate or context — so nothing is
  generated for it. Generators report it (see `SpGen`) rather than dropping it
  silently.
  """
  @spec unresolved(%__MODULE__{}) :: [{String.t(), String.t()}]
  def unresolved(%__MODULE__{unresolved: rules}) do
    Enum.map(rules, fn rule -> {rule["name"], rule["rule"] || ""} end)
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
  The effect the read model declares for an event: a real operation, `:none`
  (declared not to materialize), or `nil` — nobody has decided yet, which is
  an open question, not a decision.
  """
  @spec effect_for_event(%__MODULE__{}, String.t()) :: Esdm.effect() | nil
  def effect_for_event(%__MODULE__{read_model: rm}, event_name) when not is_nil(rm),
    do: declared_effect(rm, event_name)

  def effect_for_event(_ctx, _event_name), do: nil

  defp declared_effect(%Element{} = rm, event_name) do
    case Map.get(Esdm.declared_effects(rm), event_name) do
      :invalid -> nil
      other -> other
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

  # -- generated fixtures (the read model's `schema.examples`) -----------------
  #
  # `sp.gen.test_support` projects a read model's examples into a fixtures module
  # and a composite factory. A test that needs a *real* row must call them rather
  # than re-invent a `%{title: "sample-title"}` map or re-dispatch the create
  # command — the fixture is the model-owned projection of that row, and its id
  # (`UUID.uuid5(:dns, <key>)`) is the id every reference to it resolves to, so a
  # foreign key in one fixture already equals the primary key of the fixture it
  # points at. `fixture/1` hands a test blueprint everything it needs to name that
  # row: the primary example for a single-row seed, the plural for a collection.

  @typedoc "A generated fixture row, named from every angle a test needs."
  @type fixture_ref :: %{
          module: String.t(),
          local: String.t(),
          file: String.t(),
          function: String.t(),
          plural: String.t(),
          seed_module: String.t(),
          seed_local: String.t(),
          seed_file: String.t(),
          seed_function: String.t(),
          seed_all_function: String.t(),
          attrs: %{String.t() => String.t()}
        }

  @doc "The fixture specs of `ctx`'s read model, or `[]` when none/invalid."
  @spec fixture_specs(%__MODULE__{}) :: [SpGen.Fixtures.spec()]
  def fixture_specs(%__MODULE__{read_model: rm} = ctx) when not is_nil(rm) do
    plural = render("<domain_object>s", ctx)

    case SpGen.Fixtures.validate(rm, ctx.composite, plural) do
      {:ok, specs} -> specs
      {:error, _} -> []
    end
  end

  def fixture_specs(_ctx), do: []

  @doc "True when `ctx`'s read model declares usable fixture examples."
  @spec fixtures?(%__MODULE__{}) :: boolean()
  def fixtures?(ctx), do: fixture_specs(ctx) != []

  @doc """
  The generated-fixture reference for `ctx`'s constituent, from its **primary**
  example (the first in model order) — or `nil` when the read model declares no
  examples.
  """
  @spec fixture(%__MODULE__{}) :: fixture_ref() | nil
  def fixture(%__MODULE__{} = ctx) do
    case fixture_specs(ctx) do
      [%{} = spec | _] -> build_fixture_ref(ctx, spec)
      [] -> nil
    end
  end

  defp build_fixture_ref(%__MODULE__{} = ctx, spec) do
    fixtures_mod = SpGen.Blueprint.Fixtures.module_name(ctx)
    factory_mod = SpGen.Blueprint.Factory.module_name(ctx)

    %{
      module: fixtures_mod,
      local: fixtures_mod |> String.split(".") |> List.last(),
      file: SpGen.Blueprint.Fixtures.module_file(ctx),
      function: spec.fname,
      plural: render("<domain_object>s", ctx),
      seed_module: factory_mod,
      seed_local: factory_mod |> String.split(".") |> List.last(),
      seed_file: SpGen.Blueprint.Factory.module_file(ctx),
      seed_function: SpGen.Blueprint.Factory.seed_name(ctx),
      seed_all_function: SpGen.Blueprint.Factory.seed_all_name(ctx),
      attrs: Map.new(spec.attrs)
    }
  end

  @doc """
  The seed expression a single-row test uses to place the primary fixture:
  `<Composite>.new_<object>(<Object>Fixtures.<mnemonic>())`.
  """
  @spec seed_expr(fixture_ref()) :: String.t()
  def seed_expr(%{} = f), do: "#{f.seed_local}.#{f.seed_function}(#{f.local}.#{f.function}())"

  @doc """
  The plural seed expression a collection test uses to place every fixture:
  `<Composite>.new_<object>s(<Object>Fixtures.<plural>())`.
  """
  @spec seed_all_expr(fixture_ref()) :: String.t()
  def seed_all_expr(%{} = f),
    do: "#{f.seed_local}.#{f.seed_all_function}(#{f.local}.#{f.plural}())"

  @doc """
  The materialized source for one field of the primary example, or `nil`.

  A `*Id` field materializes as `UUID.uuid5(:dns, <key>)` — the very id the
  referenced fixture names itself with — so a reference in a generated test is a
  correct identifier without the referenced row being seeded.
  """
  @spec example_value(%__MODULE__{}, String.t()) :: String.t() | nil
  def example_value(%__MODULE__{} = ctx, name) do
    case fixture(ctx) do
      %{attrs: attrs} -> Map.get(attrs, name)
      nil -> nil
    end
  end

  @doc "The module Pascal form of a kebab name (PublicAPI, ReadModel, …)."
  def pascal(name) do
    name |> String.split("-") |> Enum.map(&String.capitalize/1) |> Enum.join()
  end
end
