defmodule SpGen.Esdm.Element do
  @moduledoc """
  A single ESDM model element: `kind` + `name` living within a `scope`, as
  loaded from one `*.esdm.yaml` document.

  * `source` — repo-relative file the element was read from
  * `address` — its stable `esdm:` reference
    (`esdm:domain=sport/bounded-context=sport/aggregate=apparatus/command=x`),
    the document head serialized, per the ESDM reference notation
  """

  @enforce_keys [:kind, :name, :scope, :doc, :source, :address]
  defstruct [:kind, :name, :scope, :doc, :source, :address]

  @type kind ::
          :domain
          | :subdomain
          | :"bounded-context"
          | :aggregate
          | :command
          | :event
          | :query
          | :"read-model"
          | :entity
          | :"value-object"
          | :policy
          | :"event-handler"
          | :"process-manager"
          | :"domain-service"
          | :actor
          | :"external-system"
          | :"context-mapping"
          | :"dynamic-consistency-boundary"
          | :feature

  @type t :: %__MODULE__{
          kind: kind(),
          name: String.t(),
          scope: [{String.t(), String.t()}],
          doc: map(),
          source: String.t(),
          address: String.t()
        }

  @doc "The name of the enclosing aggregate, if any."
  def aggregate_name(%__MODULE__{scope: scope}) do
    case List.keyfind(scope, "aggregate", 0) do
      {_kind, name} -> name
      nil -> nil
    end
  end

  @doc "The name of the read model this element refers to, if any."
  def read_model_name(%__MODULE__{doc: doc}), do: doc["readModel"]

  @doc "The `kind=name` segment for this element."
  def segment(%__MODULE__{kind: kind, name: name}), do: "#{kind}=#{name}"
end

defmodule SpGen.Esdm do
  @moduledoc """
  Loader and index for the ESDM model at `docs/domain-model/`.

  Answers the generator's data needs from the domain model so blueprint
  variables can be filled without hand-passed args:

  * `load/2` indexes every `*.esdm.yaml` document (multi-document files too),
    through a `SpGen.FS` handle.
  * `resolve/2` turns an address into exactly one element — an `esdm:`
    reference, a model file path, a `kind.name`, or a bare name. Ambiguity is
  an error listing the full `esdm:` references that disambiguate.
  * Neighborhood helpers: `aggregate_of/2`, `read_model_for/2`, `publishes/1`,
    `actors/1`, `fields/1`, `invariants/1`, `constraints/1`, `projections/1`,
    `declared_effects/1` / `declared_operation/1` (the metadata-declared
    operations), `scenarios/2`.

  YAML mappings lose key order, so `fields/1` canonicalizes deterministically:
  `id` first when present, then required fields in `required`-list order, then
  optional fields alphabetically.
  """

  alias SpGen.Esdm.Element

  defstruct [:root, :elements]

  @type t :: %__MODULE__{root: String.t(), elements: [Element.t()]}

  @doc """
  Loads all `.esdm.yaml` documents under `root` (a repo-relative path).

  Options: `:fs` — the `SpGen.FS` handle to read through (default: the disk).
  """
  @spec load(Path.t(), keyword()) :: {:ok, t()}
  def load(root, opts \\ []) do
    fs = Keyword.get(opts, :fs, SpGen.FS.default())

    elements =
      SpGen.FS.files_with(fs, root, ".esdm.yaml")
      |> Enum.flat_map(&load_file(fs, &1))

    {:ok, %__MODULE__{root: root, elements: elements}}
  end

  @doc "Like `load/1` but raises on failure."
  def load!(root, opts \\ []) do
    {:ok, model} = load(root, opts)
    model
  end

  defp load_file(fs, path) do
    with {:ok, text} <- SpGen.FS.read(fs, path),
         {:ok, docs} <- YamlElixir.read_all_from_string(text) do
      docs
      |> List.wrap()
      |> Enum.filter(&match?(%{}, &1))
      |> Enum.map(&to_element(&1, path))
    else
      _ -> []
    end
  end

  defp to_element(doc, path) do
    scope = scope_chain(doc)
    kind = String.to_atom(doc["kind"])

    %Element{
      kind: kind,
      name: doc["name"],
      scope: scope,
      doc: doc,
      source: path,
      address: build_address(scope, doc["kind"], doc["name"])
    }
  end

  # A reference is the document head serialized: scope fields written as the
  # kinds they name, then the element's own kind and name. A domain carries no
  # scope; context mappings stand alone.
  defp scope_chain(%{"kind" => kind} = doc) do
    s = doc["scope"] || %{}

    [{"domain", s["domain"]}]
    |> Enum.concat(
      for {key, k} <- [
            {"boundedContext", "bounded-context"},
            {"aggregate", "aggregate"},
            {"dynamicConsistencyBoundary", "dynamic-consistency-boundary"}
          ],
          name = s[key],
          do: {k, name}
    )
    |> Enum.reject(fn {_k, name} -> is_nil(name) end)
    |> case do
      [] when kind in ["domain", "context-mapping"] -> []
      [] -> [{"domain", doc["name"]}]
      chain -> chain
    end
  end

  @doc false
  def build_address(scope, kind, name) do
    segments = Enum.map(scope, fn {k, n} -> "#{k}=#{n}" end) ++ ["#{kind}=#{name}"]
    "esdm:" <> Enum.join(segments, "/")
  end

  @doc """
  Resolves an address into exactly one element.

  Accepted forms:

  * `esdm:domain=sport/bounded-context=sport/aggregate=apparatus/command=x`
  * a file path to a `*.esdm.yaml` file holding a single element
  * `kind.name` (e.g. `command.catalog-apparatus`)
  * a bare element name (e.g. `catalog-apparatus`)

  Option `:kinds` — the element kinds a caller accepts. It only affects
  *bare names*: the candidate set is narrowed to those kinds before the
  unique/ambiguous decision, so `sp.gen.aggregate position` resolves the
  aggregate even though a read-model shares the name. Explicit forms
  (`esdm:`, `kind.name`, file path) keep addressing whatever they name;
  a kind the caller cannot use is rejected later, by `accept_kind`.
  """
  @spec resolve(t(), String.t(), keyword()) :: {:ok, Element.t()} | {:error, term()}
  def resolve(%__MODULE__{elements: elements}, address, opts \\ []) do
    cond do
      String.starts_with?(address, "esdm:") -> resolve_reference(elements, address)
      String.ends_with?(address, ".esdm.yaml") -> resolve_file(elements, address)
      String.contains?(address, ".") -> resolve_kind_name(elements, address)
      true -> resolve_name(elements, address, Keyword.get(opts, :kinds))
    end
  end

  @doc "Like `resolve/3` but raises with a formatted message."
  def resolve!(model, address, opts \\ []) do
    case resolve(model, address, opts) do
      {:ok, element} -> element
      {:error, reason} -> raise "cannot resolve #{inspect(address)}: #{format_error(reason)}"
    end
  end

  defp resolve_reference(elements, address) do
    body = String.replace_prefix(address, "esdm:", "")

    with {:ok, segments} <- parse_segments(body) do
      target = List.last(segments)
      ancestors = Enum.slice(segments, 0..-2//1)

      matches =
        Enum.filter(elements, fn element ->
          Element.segment(element) == format_segment(target) and element.scope == ancestors
        end)

      case matches do
        [element] -> {:ok, element}
        [] -> {:error, {:unknown_reference, address}}
        many -> {:error, {:ambiguous, Enum.map(many, & &1.address)}}
      end
    end
  end

  defp format_segment({kind, name}), do: "#{kind}=#{name}"

  defp parse_segments(body) do
    segments =
      body
      |> String.split("/", trim: true)
      |> Enum.map(&String.split(&1, "=", parts: 2))

    if Enum.all?(segments, &match?([_kind, _name], &1)) do
      {:ok, Enum.map(segments, fn [k, n] -> {k, n} end)}
    else
      bad = segments |> Enum.reject(&match?([_, _], &1)) |> List.first()
      {:error, {:invalid_reference_segment, Enum.join(bad, "")}}
    end
  end

  defp resolve_file(elements, path) do
    wanted = split_path(path)

    matches = Enum.filter(elements, fn e -> suffix_match?(split_path(e.source), wanted) end)

    case matches do
      [element] ->
        {:ok, element}

      [] ->
        {:error, {:file_not_in_model, path}}

      many ->
        {:error,
         {:ambiguous_file, path,
          Enum.map(many, fn e -> "#{Element.segment(e)}  #{e.address}" end)}}
    end
  end

  defp split_path(path) do
    path
    |> String.replace_prefix("./", "")
    |> Path.split()
  end

  # Either side may carry extra prefix segments (absolute, repo-relative,
  # cwd-relative); the model file matches when one is a segment-suffix of the
  # other.
  defp suffix_match?(a, b) do
    {longer, shorter} = if length(a) >= length(b), do: {a, b}, else: {b, a}
    Enum.slice(longer, -length(shorter)..-1) == shorter
  end

  defp resolve_kind_name(elements, kind_name) do
    [kind, name] = String.split(kind_name, ".", parts: 2)

    case Enum.filter(elements, fn e -> to_string(e.kind) == kind and e.name == name end) do
      [element] -> {:ok, element}
      [] -> {:error, {:unknown_element, kind_name}}
      many -> {:error, {:ambiguous, Enum.map(many, & &1.address)}}
    end
  end

  defp resolve_name(elements, name, kinds) do
    matching = Enum.filter(elements, fn e -> e.name == name end)
    narrowed = if kinds, do: Enum.filter(matching, fn e -> e.kind in kinds end), else: matching

    case narrowed do
      [element] ->
        {:ok, element}

      [] ->
        # the name exists but only in kinds this caller cannot use
        if matching != [] && kinds != [] do
          {:error, {:kind_mismatch, name, kinds, matching}}
        else
          {:error, {:unknown_element, name}}
        end

      many ->
        {:error, {:ambiguous, Enum.map(many, & &1.address)}}
    end
  end

  @doc "Renders a resolution error for CLI output."
  def format_error({:ambiguous, addresses}) do
    "the name is ambiguous, use one of these esdm: references:\n" <>
      Enum.map_join(addresses, "\n", fn a -> "  " <> a end)
  end

  def format_error({:ambiguous_file, path, elements}) do
    "the file #{path} holds more than one element — pass an esdm: reference:\n" <>
      Enum.map_join(elements, "\n", fn e -> "  " <> e end)
  end

  def format_error({:kind_mismatch, name, kinds, found}) do
    "no #{kinds |> Enum.map(&to_string/1) |> Enum.join("/")} element named \"#{name}\" — " <>
      "the name exists as:\n" <>
      Enum.map_join(found, "\n", fn e ->
        "  #{e.address} (try `#{e.kind}.#{e.name}` or this reference)"
      end)
  end

  def format_error({:unknown_reference, address}), do: "no such element: #{address}"
  def format_error({:unknown_element, name}), do: "no such element: #{name}"
  def format_error({:file_not_in_model, path}), do: "not an element of the model: #{path}"
  def format_error({:invalid_reference_segment, s}), do: "invalid reference segment: #{s}"

  # -- neighborhood --------------------------------------------------------

  @doc "Finds an element by kind and name."
  @spec find(t(), Element.kind(), String.t()) :: {:ok, Element.t()} | {:error, :not_found}
  def find(%__MODULE__{elements: elements}, kind, name) do
    case Enum.find(elements, fn e -> e.kind == kind and e.name == name end) do
      nil -> {:error, :not_found}
      element -> {:ok, element}
    end
  end

  @doc "All elements with kind `event` owned by the aggregate named `name`, sorted."
  @spec events_of(t(), String.t()) :: [Element.t()]
  def events_of(%__MODULE__{elements: elements}, name) do
    elements
    |> Enum.filter(fn e -> e.kind == :event and Element.aggregate_name(e) == name end)
    |> Enum.sort_by(& &1.name)
  end

  @doc "The aggregate owning the given element (via `scope.aggregate`)."
  def aggregate_of(%__MODULE__{} = model, %Element{} = element) do
    case Element.aggregate_name(element) do
      nil -> {:error, :not_found}
      name -> find(model, :aggregate, name)
    end
  end

  @doc """
  The read model for an element: its `readModel` for queries, the
  same-named read model otherwise (aggregate/read-model share the constituent
  name, which ESDM allows on purpose).
  """
  def read_model_for(%__MODULE__{} = model, %Element{kind: kind, name: name} = element) do
    case kind do
      :query ->
        case Element.read_model_name(element) do
          nil -> {:error, :not_found}
          rm -> find(model, :"read-model", rm)
        end

      _ ->
        find(model, :"read-model", Element.aggregate_name(element) || name)
    end
  end

  @doc "Event names published by a command."
  def publishes(%Element{doc: doc}), do: List.wrap(doc["publishes"])

  @doc "Actor names allowed to issue an element."
  def actors(%Element{doc: doc}), do: List.wrap(doc["actors"])

  @doc "The `description` of a document, if it has one."
  def describe(%Element{doc: doc}), do: doc["description"]

  @doc """
  Data fields of a command/event, or state/schema of an aggregate/read model,
  or result items of a query. Deterministic order (see module docs).
  """
  def fields(%Element{doc: doc}) do
    schema = data_schema(doc)
    properties = schema["properties"] || %{}
    required = List.wrap(schema["required"])

    {reqs, opts} =
      properties
      |> Enum.map(fn {name, spec} -> field(name, spec, name in required) end)
      |> Enum.split_with(& &1.required)

    reqs = Enum.sort_by(reqs, fn f -> Enum.find_index(required, &(&1 == f.name)) end)
    opts = Enum.sort_by(opts, & &1.name)

    id_first(reqs ++ opts)
  end

  # Commands/events carry `data`, aggregates `state`, read models `schema`,
  # queries `result` (which may be an array of items).
  defp data_schema(%{"data" => data}) when is_map(data), do: data
  defp data_schema(%{"state" => state}) when is_map(state), do: state
  defp data_schema(%{"schema" => schema}) when is_map(schema), do: schema

  defp data_schema(%{"result" => %{"type" => "array", "items" => items}}) when is_map(items),
    do: items

  defp data_schema(%{"result" => result}) when is_map(result), do: result
  defp data_schema(_doc), do: %{}

  defp field(name, spec, required) do
    %{
      name: name,
      type: spec["type"] || "string",
      format: spec["format"],
      description: spec["description"],
      required: required
    }
  end

  defp id_first(fields) do
    {ids, rest} = Enum.split_with(fields, &(&1.name == "id"))
    ids ++ rest
  end

  @doc "Aggregate invariants as `%{name:, rule:}`."
  def invariants(%Element{doc: doc}), do: List.wrap(doc["invariants"])

  # -- declared operations (metadata.annotations) --------------------------------
  #
  # The rule prose on a projection is for humans; what an event DOES to the
  # read model is declared, machine-readable, in the element's metadata —
  # namespaced under `spgen.` so the shared annotations bag stays collision
  # free for every other tool:
  #
  #   command:     metadata.annotations."spgen.operation":
  #                create | update | delete | none
  #   query:       metadata.annotations."spgen.operation":
  #                read | collection      (optional — see below)
  #   read-model:  metadata.annotations."spgen.operation.<event>":
  #                create | update | delete | none
  #
  # `none` is a decision — "somebody looked and nothing materializes" — which
  # is not the same thing as the absence of any annotation. On a command it
  # reads "dispatch facts, change no read model": the API answers `:ok`, the
  # endpoint 204, and no row is read back.
  #
  # A query may declare which read it is: `collection` says the parameters are
  # the JSON:API set (`filter`/`sort`/`page`/`fields`) and the answer is the
  # live read-model table, which is what `SpGen.Blueprint.Query` generates
  # against the shared `QueryBuilder`. It is OPTIONAL: a query that declares
  # nothing falls back to its `result` shape, so a model written before the
  # annotation stays valid.
  #
  # The vocabulary differs per kind, which is why `declared_operation/1` and
  # `declared_query_operation/1` are separate reads of one key.

  @operations ~w(create update delete none)
  @projection_operations @operations
  @query_operations ~w(read collection)

  @operation_key "spgen.operation"
  @effect_prefix "spgen.operation."

  @doc "The annotations key a command declares its operation under."
  def operation_key, do: @operation_key

  @doc "The annotations prefix read models declare per-event effects under."
  def effect_prefix, do: @effect_prefix

  @doc "The `metadata.annotations` map of an element (`%{}` when absent)."
  @spec annotations(Element.t()) :: map()
  def annotations(%Element{doc: doc}) do
    get_in(doc, ["metadata", "annotations"]) || %{}
  end

  @doc """
  The operation a **command** document declares: `:create | :update | :delete |
  :none`, or `nil` when absent or not in the command vocabulary.
  """
  @spec declared_operation(Element.t()) :: :create | :update | :delete | :none | nil
  def declared_operation(%Element{} = element) do
    case annotations(element)[@operation_key] do
      v when v in @operations -> String.to_atom(v)
      _ -> nil
    end
  end

  @doc """
  The operation a **query** document declares: `:read | :collection`, or `nil`
  when it declares none (or names something outside the query vocabulary —
  `mix sp.check` reports the bad value, generation must not read meaning from
  a typo).
  """
  @spec declared_query_operation(Element.t()) :: :read | :collection | nil
  def declared_query_operation(%Element{} = element) do
    case annotations(element)[@operation_key] do
      v when v in @query_operations -> String.to_atom(v)
      _ -> nil
    end
  end

  @typedoc "A declared effect on a read model: a real operation, or `:none`."
  @type effect :: :create | :update | :delete | :none

  @doc """
  The declared effects of a **read model** as `%{event_name => effect}`,
  from its `spgen.operation.<event>` annotation keys. Invalid or unknown
  values are not silently dropped — they surface as `:invalid` so
  `mix sp.check` and the generators can point at the exact mistake.
  """
  @spec declared_effects(Element.t()) :: %{String.t() => effect() | :invalid}
  def declared_effects(%Element{} = element) do
    for {key, value} <- annotations(element),
        String.starts_with?(key, @effect_prefix),
        event = String.replace_prefix(key, @effect_prefix, ""),
        event != "",
        into: %{} do
      {event,
       cond do
         value in @operations -> String.to_atom(value)
         true -> :invalid
       end}
    end
  end

  @doc "Vocabulary of the bare `spgen.operation` annotation (commands)."
  def operations, do: @operations

  @doc "Vocabulary of the `spgen.operation.<event>` annotations (read models)."
  def projection_operations, do: @projection_operations

  @doc "Vocabulary of the bare `spgen.operation` annotation (queries)."
  def query_operations, do: @query_operations

  @doc """
  The parameter names a query's `parameters.properties` declares (`filter`,
  `sort`, `page`, `fields` …).
  """
  @spec query_parameter_names(Element.t()) :: [String.t()]
  def query_parameter_names(%Element{} = element) do
    element |> param_properties([]) |> Map.keys() |> Enum.sort()
  end

  @doc """
  The fields a query declares sortable: the `sortableFields` list on its
  `parameters.properties.sort` entry. JSON:API `sort` is a comma-separated
  *string*, so the names are not nested `properties` the way `filter`'s are —
  the field list is a fact about the string, not an object shape. A model that
  lists none leaves sorting to whatever its `filter` names.
  """
  @spec sortable_fields(Element.t()) :: [String.t()]
  def sortable_fields(%Element{doc: doc}) do
    doc
    |> get_in(["parameters", "properties", "sort", "sortableFields"])
    |> List.wrap()
    |> Enum.map(&to_string/1)
  end

  @doc """
  How a query paginates, from its `parameters.properties.page`: `:none` when the
  model declares no `page` parameter at all, `:offset` when it names
  `limit`/`offset`, and `:numbered` (`number`/`size`) otherwise — including a
  bare `page` that states no properties, since `number`/`size` is the house
  style `Sportipedia.Support.JSONAPI.QueryBuilder` defaults to.
  """
  @spec page_style(Element.t()) :: :numbered | :offset | :none
  def page_style(%Element{doc: doc}) do
    case get_in(doc, ["parameters", "properties"]) do
      props when is_map(props) ->
        case Map.get(props, "page") do
          page when is_map(page) -> page_style_of(Map.get(page, "properties"))
          nil -> :none
        end

      _ ->
        :none
    end
  end

  defp page_style_of(props) when is_map(props) do
    keys = Map.keys(props)

    cond do
      Enum.any?(keys, &(&1 in ["number", "size"])) -> :numbered
      Enum.any?(keys, &(&1 in ["limit", "offset"])) -> :offset
      true -> :numbered
    end
  end

  defp page_style_of(_), do: :numbered

  # `parameters.properties.<path>` as a map, `%{}` when the model says nothing
  defp param_properties(%Element{doc: doc}, path) do
    case get_in(doc, ["parameters", "properties"] ++ path) do
      map when is_map(map) -> map
      _ -> %{}
    end
  end

  @doc "Command constraints as `%{name:, rule:}`."
  def constraints(%Element{doc: doc}), do: List.wrap(doc["constraints"])

  @doc "Projection entries of a read model: `%{event:, aggregate:, rule:}`."
  def projections(%Element{doc: doc}), do: List.wrap(doc["projections"])

  @doc """
  The feature scenarios that exercise the given operation (by its `when`
  command/query name), in model order.
  """
  def scenarios(%__MODULE__{elements: elements}, %Element{name: operation_name}) do
    for feature <- elements,
        feature.kind == :feature,
        scenario <- List.wrap(feature.doc["scenarios"]),
        get_in(scenario, ["when", "command"]) == operation_name or
          get_in(scenario, ["when", "query"]) == operation_name,
        do: scenario
  end
end
