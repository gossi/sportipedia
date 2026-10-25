defmodule Sportipedia.Codegen.Placeholders do
  @moduledoc """
  Substitution engine for blueprint templates.

  Placeholders are enclosed in angle-brackets and use a formal syntax to
  express the case needed at that position, see
  `/docs/architecture/naming-substitution.md`:

  | Case        | One Word     | Two Words          |
  | ----------- | ------------ | ------------------ |
  | kebap-case  | `<-subdomain>` | `<domain-object>` |
  | snake_case  | `<_subdomain>` | `<domain_object>` |
  | PascalCase  | `<Subdomain>`  | `<DomainObject>`  |
  | camelCase   | `<subdomain>`  | `<domainObject>`  |
  | spaces      | -              | `<describe the situation>` |

  A placeholder whose words match a known *variable* (see `variables/0`) is a
  variable placeholder: its value is re-cased according to the notation.
  Anything else is a *slot*: free prose filled in verbatim from the slots map
  (documentation prose, field types, and similar context values).

  A variable placeholder immediately followed by `s` (at a word boundary)
  pluralizes its rendered value, per the samples in the naming doc, e.g.
  `<domain-object>s` -> `apparatuses`, `<DomainObject>s` -> `Apparatuses`.
  `s` as part of following text (`<DomainObject>Aggregate`) is left alone.

  Rendering is total: a placeholder missing from both `vars` and `slots`
  raises, so template/data mismatches surface as compile-time-ish errors of
  the generator rather than as broken output.
  """

  @placeholder_pattern ~r/<([^<>]*)>(s(?![A-Za-z0-9_]))?/

  @variables ~w(
    command event subdomain operation entity value_object composite
    constituent domain_object query public_api action jsonapi_type field
    validator object
  )

  @typedoc "The ESDM/architecture variables that carry a domain name."
  @type variable :: String.t()

  @doc "The known variable names, in canonical snake_case."
  def variables, do: @variables

  @doc """
  Renders `template`, substituting every placeholder.

  - `vars` maps canonical variable names (strings, snake_case) to their raw
    domain value (any of kebab/snake/camel/Pascal forms; re-cased per
    placeholder notation).
  - `slots` maps the exact raw placeholder text to verbatim replacement text.

  Raises `ArgumentError` listing all unresolved placeholders.
  """
  @spec render(String.t(), %{vars: map(), slots: map()}) :: String.t()
  def render(template, %{vars: vars, slots: slots}) do
    case unresolved(template, vars, slots) do
      [] ->
        do_render(template, vars, slots)

      unknown ->
        raise ArgumentError,
              "unresolved placeholder(s) in template: #{Enum.map_join(unknown, ", ", &"<#{&1}>")}"
    end
  end

  @doc "Like `render/2` but returns `{:error, unknown_placeholders}` instead of raising."
  @spec fill(String.t(), %{vars: map(), slots: map()}) ::
          {:ok, String.t()} | {:error, [String.t()]}
  def fill(template, %{vars: vars, slots: slots}) do
    case unresolved(template, vars, slots) do
      [] -> {:ok, do_render(template, vars, slots)}
      unknown -> {:error, unknown}
    end
  end

  @doc "Lists placeholder bodies (raw inner text) that neither `vars` nor `slots` resolve."
  @spec unresolved(String.t(), map(), map()) :: [String.t()]
  def unresolved(template, vars, slots) do
    for raw <- bodies(template),
        not resolvable?(raw, vars, slots),
        do: raw
  end

  defp resolvable?(raw, vars, slots) do
    case classify(raw) do
      {:variable, key, _casing} -> Map.has_key?(vars, key)
      {:slot, text} -> Map.has_key?(slots, text)
    end
  end

  defp do_render(template, vars, slots) do
    Regex.replace(@placeholder_pattern, template, fn _whole, raw, plural ->
      case classify(raw) do
        {:variable, key, casing} -> render_value(Map.fetch!(vars, key), casing, plural)
        {:slot, text} -> Map.fetch!(slots, text) <> plural
      end
    end)
  end

  # Slots keep their exact inner text as key; variables are recognized by
  # their canonical word list.
  defp classify(raw) do
    {casing, core} = casing_of(raw)
    words = words(core)

    cond do
      casing == :prose ->
        {:slot, raw}

      words != [] and Enum.join(words, "_") in @variables ->
        {:variable, Enum.join(words, "_"), casing}

      true ->
        {:slot, raw}
    end
  end

  defp casing_of(body) do
    cond do
      String.starts_with?(body, "-") -> {:kebab, String.slice(body, 1..-1//1)}
      String.starts_with?(body, "_") -> {:snake, String.slice(body, 1..-1//1)}
      String.contains?(body, " ") -> {:prose, body}
      String.contains?(body, "-") -> {:kebab, body}
      String.contains?(body, "_") -> {:snake, body}
      body =~ ~r/^[A-Z]/ -> {:pascal, body}
      body =~ ~r/[A-Z]/ -> {:camel, body}
      true -> {:camel, body}
    end
  end

  @doc """
  Splits a placeholder core into lowercase words, honoring kebap, snake,
  camel and Pascal casing plus acronym runs (`PublicAPI` -> [public, api]).
  """
  @spec words(String.t()) :: [String.t()]
  def words(core) do
    core
    |> String.replace(~r/[-_ ]+/, ".")
    |> String.split(".", trim: true)
    |> Enum.flat_map(&split_camel/1)
    |> Enum.map(&String.downcase/1)
  end

  defp split_camel(token) do
    Regex.scan(~r/[A-Z]+(?![a-z])|[A-Z]?[a-z0-9]+/, token)
    |> List.flatten()
  end

  defp render_value(value, casing, plural) do
    parts = value |> to_string() |> words()
    parts = if parts == [], do: [to_string(value)], else: parts

    text = render_parts(parts, casing)
    if plural == "s", do: pluralize(text), else: text
  end

  defp render_parts(parts, :kebab), do: Enum.join(parts, "-")
  defp render_parts(parts, :snake), do: Enum.join(parts, "_")
  defp render_parts(parts, :pascal), do: parts |> Enum.map(&capitalize/1) |> Enum.join()

  defp render_parts(parts, :camel) do
    parts |> Enum.map(&capitalize/1) |> List.update_at(0, &String.downcase/1) |> Enum.join()
  end

  defp render_parts(_parts, :prose), do: raise(ArgumentError, "prose is filled as a slot")

  @doc false
  def pluralize(text) do
    cond do
      text =~ ~r/[cs]h$/i -> text <> "es"
      text =~ ~r/[sxz]$/i -> text <> "es"
      text =~ ~r/[^aeiouy]y$/i -> String.replace_suffix(text, "y", "ies")
      true -> text <> "s"
    end
  end

  defp capitalize(""), do: ""
  defp capitalize(word), do: String.capitalize(word)

  @doc "All placeholder bodies (raw inner text) in `template`, in order."
  @spec bodies(String.t()) :: [String.t()]
  def bodies(template) do
    for [_whole, inner | _rest] <- Regex.scan(@placeholder_pattern, template), do: inner
  end
end
