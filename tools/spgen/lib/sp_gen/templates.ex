defmodule SpGen.Templates do
  @moduledoc """
  Line-level composition shared by blueprints: field lines, validation lines,
  indentation and deterministic sample values for generated tests.

  Sample values come from the domain model's `feature` scenarios whenever one
  exists for the operation; without a scenario, values fall back to
  `UUID.uuid4()` for ids and quoted `"sample-<field>"` strings — always the
  same for the same model, keeping runs deterministic.
  """

  alias SpGen.Context

  @doc "Indent every non-empty line of `text` with `n` spaces."
  def indent(text, n \\ 2) do
    pad = String.duplicate(" ", n)

    text
    |> String.split("\n")
    |> Enum.map(fn line -> if(line == "", do: "", else: pad <> line) end)
    |> Enum.join("\n")
  end

  @doc """
  The `field` line for one data field.

      iex> SpGen.Templates.field_line(%{name: "title", type: "string", required: true})
      "field :title, String.t(), enforce: true"
  """
  def field_line(%{name: name} = field) do
    type = Context.elixir_type(field)
    base = "field :#{name}, #{type}"
    if field.required, do: base <> ", enforce: true", else: base
  end

  @doc """
  The `validates` line for one field, merging presence with validators.

  Validators attached to the field add `by: [function: &Module.validate/2]`;
  `:unique` validators also add `allow_nil: true` (a partial update may omit
  the field), `:exists` validators do not.
  """
  def validates_line(field, validators) do
    validators = Enum.filter(validators, &(&1.field == field.name))

    parts =
      if field.required && !field.internal, do: ["presence: true"], else: []

    parts =
      Enum.reduce(validators, parts, fn v, acc ->
        by = "by: [function: &#{v.module}.validate/2"
        # allow_nil belongs inside the by-list: Vex skips the validator for nil
        by = if v.kind == :unique, do: by <> ", allow_nil: true", else: by
        acc ++ [by <> "]"]
      end)

    if parts == [] do
      nil
    else
      "validates :#{field.name}, " <> Enum.join(parts, ", ")
    end
  end

  @doc """
  All validates lines for a context (required fields and validator fields).
  """
  def validates_lines(%Context{} = ctx) do
    ctx.fields
    |> Enum.map(&validates_line(&1, ctx.validators))
    |> Enum.reject(&is_nil/1)
  end

  @doc "Sample source value for a field, preferring scenario data."
  def sample_value(%Context{} = _ctx, %{name: "id"}), do: "UUID.uuid4()"

  # typed fields get type-correct literals: the DB would reject a
  # `"sample-apparatusId"` for a `:binary_id` column
  def sample_value(%Context{} = _ctx, %{format: "uuid"}), do: "UUID.uuid4()"
  def sample_value(%Context{} = _ctx, %{format: "date-time"}), do: "DateTime.utc_now()"
  def sample_value(%Context{} = _ctx, %{type: "integer"}), do: "1"
  def sample_value(%Context{} = _ctx, %{type: "number"}), do: "1.0"
  def sample_value(%Context{} = _ctx, %{type: "boolean"}), do: "true"
  def sample_value(%Context{} = _ctx, %{type: "array"}), do: "[]"
  def sample_value(%Context{} = _ctx, %{type: "object"}), do: "%{}"

  def sample_value(%Context{} = ctx, %{name: name} = field) do
    case scenario_value(ctx, name) do
      nil -> field |> default_value() |> inspect_value()
      value -> inspect_value(value)
    end
  end

  defp scenario_value(%Context{scenarios: [first | _]}, name) do
    get_in(first, ["when", "data", name])
  end

  defp scenario_value(_ctx, _name), do: nil

  defp default_value(%{name: name}), do: "sample-#{name}"

  defp inspect_value(value) when is_binary(value), do: inspect(value)
  defp inspect_value(value), do: inspect(value)

  @doc "Struct literal body `key: value, ...` for all of the context's fields."
  def struct_body(%Context{} = ctx, overrides \\ %{}) do
    ctx.fields
    |> Enum.map(fn f ->
      value =
        case Map.fetch(overrides, f.name) do
          {:ok, override} -> override
          :error -> sample_value(ctx, f)
        end

      "#{f.name}: #{value}"
    end)
    |> Enum.join(", ")
  end
end
