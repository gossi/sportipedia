defmodule SpGen.Fixtures do
  @moduledoc """
  The fixture identity rule, shared by `sp.gen.test_support` and `mix sp.check`.

  A fixture is a read-model instance the domain model *declares*: the read
  model's `schema.examples` entries. Each example names itself with a fixture
  key — three kebab-case segments, `<composite>:<read-model>:<mnemonic>` —
  carried in its `id` property. Generated code materializes keys as

      UUID.uuid5(:dns, "<key>")

  so every fixture id, and every reference from one fixture to another, is a
  real, `format: uuid`-valid value derived from one rule. `:dns` is the RFC
  4122 public namespace; the colon in the grammar already segregates these
  inputs from anything a DNS-namespaced hash would legitimately see.

  This module owns the key grammar, the validation of a read model's examples
  against its schema block and its composite, the wrap decision for field
  values, and the code names a key produces. It raises nothing and writes
  nothing — `{:error, [messages]}` is its answer to a bad model, listing every
  violation so one pass over the YAML fixes the file.
  """

  alias SpGen.Esdm
  alias SpGen.Esdm.Element

  @kebab ~r/^[a-z][a-z0-9-]*$/
  @key ~r/^[a-z][a-z0-9-]*(:[a-z][a-z0-9-]*){2}$/
  @uuid ~r/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/

  @elixir_nonames ~w(do end when case cond and or not in fn else true false nil)

  @typedoc "A parsed fixture key."
  @type key :: {composite :: String.t(), read_model :: String.t(), mnemonic :: String.t()}

  @typedoc "One example, prepared for rendering into fixture code."
  @type spec :: %{
          key: String.t(),
          parts: key(),
          fname: String.t(),
          attrs: [{String.t(), String.t()}]
        }

  @doc "True when `value` is a well-formed fixture key (three kebab segments)."
  @spec fixture_key?(term()) :: boolean()
  def fixture_key?(value) when is_binary(value), do: Regex.match?(@key, value)
  def fixture_key?(_value), do: false

  @doc "The parsed parts of a fixture key."
  @spec parse_key(String.t()) :: {:ok, key()} | {:error, String.t()}
  def parse_key(value) when is_binary(value) do
    if fixture_key?(value) do
      [composite, read_model, mnemonic] = String.split(value, ":")
      {:ok, {composite, read_model, mnemonic}}
    else
      {:error,
       "\"#{value}\" is not a fixture key — expected <composite>:<read-model>:<mnemonic> " <>
         "with kebab-case segments"}
    end
  end

  def parse_key(_value), do: {:error, "a fixture key must be a string"}

  @doc """
  The code name a key produces: its mnemonic, snake-cased.
  `equipment:apparatus:parallel-bars` → `parallel_bars`.
  """
  @spec function_name(String.t()) :: String.t()
  def function_name(key) do
    {_composite, _read_model, mnemonic} = parts!(key)
    String.replace(mnemonic, "-", "_")
  end

  @doc """
  The materialization of one example value in generated fixture code:

  * a fixture key → `UUID.uuid5(:dns, key)`
  * a `*Id` field whose value is neither a key nor a UUID → wrapped as well —
    the fail-safe reading: it is a key spelled wrong, never a value to keep
  * anything else → the literal, as `inspect` source
  """
  @spec materialize(String.t(), term()) :: String.t()
  def materialize(field, value) do
    cond do
      fixture_key?(value) -> uuid_expr(value)
      reference_field?(field) and is_binary(value) and not uuid?(value) -> uuid_expr(value)
      true -> inspect(value)
    end
  end

  @doc "True when the value is a canonical UUID string (kept as a literal)."
  @spec uuid?(String.t()) :: boolean()
  def uuid?(value) when is_binary(value), do: Regex.match?(@uuid, value)
  def uuid?(_value), do: false

  @doc "True for reference fields — the `*Id` naming the schema blocks use."
  @spec reference_field?(String.t()) :: boolean()
  def reference_field?(field), do: String.ends_with?(field, "Id")

  defp uuid_expr(key), do: "UUID.uuid5(:dns, #{inspect(key)})"

  @doc "The `examples` list declared on a read model element, in model order."
  @spec examples(Element.t()) :: [map()]
  def examples(%Element{doc: doc}) do
    doc |> get_in(["schema", "examples"]) |> List.wrap() |> Enum.filter(&is_map/1)
  end

  @doc """
  Validate a read model's examples and prepare renderable specs.

  * `composite` — the read model's own composite (from the model layout); an
    example's key must name it, and the read model
  * `plural` — the aggregate function name the generated file will define; no
    mnemonic may produce the same name

  `{:ok, specs}` carries every example (model order, schema-declared field
  order); `{:error, messages}` lists *every* violation, never just the first.
  """
  @spec validate(Element.t(), String.t(), String.t()) ::
          {:ok, [spec()]} | {:error, [String.t()]}
  def validate(%Element{} = element, composite, plural) do
    fields = Esdm.fields(element)
    properties = Enum.map(fields, & &1.name)
    required = for f <- fields, f.required, do: f.name

    element
    |> examples()
    |> Enum.reduce({[], []}, fn example, {specs, errors} ->
      messages =
        unknown_keys(example, properties) ++
          missing_required(example, required) ++
          check_id(example, element, composite) ++
          check_references(example) ++
          check_fname(example, plural)

      case messages do
        [] ->
          {specs ++ [spec(example, properties)], errors}

        found ->
          {specs, errors ++ Enum.map(found, &"#{element.source}: #{&1}")}
      end
    end)
    |> case do
      {_, [_ | _] = errors} ->
        {:error, errors}

      {specs, []} ->
        case duplicate_fnames(specs) do
          [] -> {:ok, specs}
          duplicates -> {:error, Enum.map(duplicates, &"#{element.source}: #{&1}")}
        end
    end
  end

  defp unknown_keys(example, properties) do
    (Map.keys(example) -- properties)
    |> Enum.map(fn key ->
      "example #{example_label(example)} carries \"#{key}\", which the schema does not declare"
    end)
  end

  defp missing_required(example, required) do
    (required -- Map.keys(example))
    |> Enum.map(fn key ->
      "example #{example_label(example)} is missing required property \"#{key}\""
    end)
  end

  defp check_id(example, %Element{name: rm_name}, composite) do
    case Map.get(example, "id") do
      nil ->
        [
          "example #{example_label(example)} carries no id — fixtures name themselves with a fixture key"
        ]

      id ->
        case parse_key(id) do
          {:error, reason} ->
            [reason]

          {:ok, {^composite, ^rm_name, _mnemonic}} ->
            []

          {:ok, {other_composite, other_rm, _mnemonic}} ->
            [
              "fixture key #{inspect(id)} names #{inspect(other_composite)}/#{inspect(other_rm)}, " <>
                "but this read model lives in #{inspect(composite)}/#{inspect(rm_name)} — a key must name its own home"
            ]
        end
    end
  end

  defp check_references(example) do
    example
    |> Enum.filter(fn {field, value} -> reference_field?(field) && is_binary(value) end)
    |> Enum.flat_map(fn {_field, value} ->
      cond do
        fixture_key?(value) -> []
        uuid?(value) -> []
        true -> ["reference value #{inspect(value)} is neither a fixture key nor a UUID"]
      end
    end)
  end

  defp check_fname(%{"id" => id}, plural) when is_binary(id) do
    if fixture_key?(id) do
      fname = function_name(id)

      cond do
        fname in @elixir_nonames ->
          ["#{fname}/0 would shadow an Elixir keyword — rename the mnemonic"]

        fname == plural ->
          [
            "fixture key #{inspect(id)} would define #{plural}/0, colliding with the " <>
              "aggregate function of the same file"
          ]

        true ->
          []
      end
    else
      []
    end
  end

  defp check_fname(_example, _plural), do: []

  defp spec(%{"id" => id} = example, properties) do
    {:ok, parts} = parse_key(id)

    attrs =
      properties
      |> Enum.filter(&Map.has_key?(example, &1))
      |> Enum.map(fn name -> {name, materialize(name, example[name])} end)

    %{key: id, parts: parts, fname: function_name(id), attrs: attrs}
  end

  defp duplicate_fnames(specs) do
    specs
    |> Enum.frequencies_by(& &1.fname)
    |> Enum.flat_map(fn {fname, count} ->
      if count > 1 do
        ["two examples both name function #{fname}/0 — mnemonics must differ"]
      else
        []
      end
    end)
  end

  defp parts!(key) do
    {:ok, parts} = parse_key(key)
    parts
  end

  defp example_label(%{"id" => id}) when is_binary(id), do: inspect(id)
  defp example_label(example), do: inspect(Map.get(example, "title", "<unnamed>"))

  @doc "Every fixture key referenced from a read model's example fields."
  @spec referenced_keys(Element.t()) :: [String.t()]
  def referenced_keys(%Element{} = element) do
    for example <- examples(element),
        {field, value} <- example,
        reference_field?(field),
        is_binary(value),
        fixture_key?(value),
        do: value
  end

  @doc "Every fixture key the read model's examples define (its own ids)."
  @spec defined_keys(Element.t()) :: [String.t()]
  def defined_keys(%Element{} = element) do
    for example <- examples(element),
        id = Map.get(example, "id"),
        is_binary(id),
        fixture_key?(id),
        do: id
  end

  @doc "True for single kebab-case words (one grammar segment)."
  @spec kebab?(String.t()) :: boolean()
  def kebab?(value), do: Regex.match?(@kebab, value)
end
