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

  Validators attached to the field add `by: [function: &Module.validate/2]`
  with the skip option the pattern demands: `:unique` adds `allow_nil: true`
  (a partial update may omit the field), `:exists` adds `allow_blank: true`
  (the by-id lookup must never see an absent or empty id — see
  `validates_by_pair/2`), and a `:rule` pair on a field the model does not
  require adds `allow_nil: true` — a generated rule body reads the value, and
  the scaffold raises on any value at all, nil included.

  Two validators on one field therefore produce **two `by:` pairs in one call**:

      validates :apparatusId,
        by: [function: &AtMostOneEquipment.validate/2],
        by: [function: &EquipmentExists.validate/2]

  That is not a mistake to clean up — it is the only shape Vex accepts.
  `Vex.Struct.validates/2` stores validations with `Map.put(validations, field,
  opts)`, so a *second call* for the same field replaces the first one and its
  rule silently disappears. Within one call the validations are a keyword list
  that `Vex.results/2` maps pair by pair, so duplicate `by:` keys both run and
  both report their error (verified against vex 0.9.2:
  `[{:error, :x, :by, :a_says_no}, {:error, :x, :by, :b_says_no}]`).
  """
  def validates_line(field, validators) do
    parts =
      if(validates_presence?(field), do: ["presence: true"], else: []) ++
        Enum.map(validators_for(field, validators), &validates_by_pair(&1, field))

    case parts do
      [] -> nil
      parts -> "validates :#{field.name}, " <> Enum.join(parts, ", ")
    end
  end

  @doc "Does `field` owe the line a `presence: true` part?"
  def validates_presence?(field), do: field.required && !field.internal

  @doc "The validators guarding `field`, in the order their `by:` parts appear."
  def validators_for(%{name: name}, validators), do: Enum.filter(validators, &(&1.field == name))

  @doc """
  The `by:` pair for one validator — the exact text a `validates` line needs.
  The skip option belongs inside the pair: Vex does not run the validator for
  a value the option covers (`Vex.Skipping.skip?/2`).

  * `:unique` → `allow_nil: true`: a partial update may omit the field, and an
    omitted value claims nothing on uniqueness.
  * `:exists` → `allow_blank: true`: the check is a round trip on the primary
    key and `Repo.get/2` raises on nil and on `""` — a 500 for a request the
    command could answer. `allow_blank` covers absent *and* empty
    (`Vex.Blank.blank?/1`); `allow_nil` alone would still run the lookup on
    `""`, and a `:not_found` for a blank id is collapsed by the
    `ErrorClassifier` into a whole-command 404 instead of the 422 `presence`
    gives it.
  * `:rule` on a field the model does not require → `allow_nil: true`: the
    scaffold raises its `TODO:` on every value — nil included — and a finished
    rule body may `String.downcase` the value before looking at the context,
    which raises the same way. An absent optional field claims nothing. An
    operator who finishes the body into a pure cross-field check — one that
    ignores the value it is called with — may drop the skip option again; the
    needle (`validates_needle/1`) does not read it.
  * `:rule` on a required field → none: `enforce: true` means the struct
    cannot be built without a value here, so there is no nil to skip.
  """
  def validates_by_pair(%{kind: kind, module: module}, field) do
    base = "by: [function: &#{module}.validate/2"

    case kind do
      :unique -> base <> ", allow_nil: true]"
      :exists -> base <> ", allow_blank: true]"
      :rule -> if(field.required, do: base <> "]", else: base <> ", allow_nil: true]")
    end
  end

  @doc """
  The text a `validates` line must contain for this validator to run at all —
  what `Spgen.Blueprint.Command` compares against the parsed file.
  """
  def validates_needle(%{module: module}), do: "&#{module}.validate/2"

  @doc """
  All validates lines for a context (required fields and validator fields).
  """
  def validates_lines(%Context{} = ctx) do
    ctx.fields
    |> Enum.map(&validates_line(&1, ctx.validators))
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Sample source value for a field.

  * **plain fields** — the happy feature scenario's `when.data`, then the read
    model's primary example, then a type-correct default, then `"sample-<field>"`.
  * **ids and `*Id` references** — the primary example, then a type-correct
    default. Never the scenario: a scenario's id is the `{{ generated }}`
    sentinel, a placeholder for the system's own key, not a value to inject.

  The example is the same fixture `sp.gen.test_support` projects, so a generated
  test and a seeded row carry one value — and a `*Id` reference becomes the very
  `UUID.uuid5(:dns, <key>)` the referenced fixture names itself with, so a
  foreign key already points at the row it seeds. `example_value` is already
  materialized source, returned verbatim.
  """
  def sample_value(%Context{} = ctx, %{name: _name} = field) do
    if structural?(field) do
      structural_source(ctx, field)
    else
      prose_source(ctx, field)
    end
  end

  defp structural?(%{name: name} = field) do
    name == "id" or field[:format] == "uuid" or SpGen.Fixtures.reference_field?(name)
  end

  defp structural_source(ctx, field) do
    case Context.example_value(ctx, field.name) do
      nil -> typed_default(field)
      source -> source
    end
  end

  defp prose_source(ctx, field) do
    case scenario_value(ctx, field.name) do
      nil -> prose_no_scenario(ctx, field)
      value -> inspect_value(value)
    end
  end

  defp prose_no_scenario(ctx, field) do
    case Context.example_value(ctx, field.name) do
      nil -> typed_default(field)
      source -> source
    end
  end

  # typed fields get type-correct literals: the DB would reject a
  # `"sample-apparatusId"` for a `:binary_id` column
  defp typed_default(%{name: "id"}), do: "UUID.uuid4()"
  defp typed_default(%{format: "uuid"}), do: "UUID.uuid4()"
  defp typed_default(%{format: "date-time"}), do: "DateTime.utc_now()"
  defp typed_default(%{type: "integer"}), do: "1"
  defp typed_default(%{type: "number"}), do: "1.0"
  defp typed_default(%{type: "boolean"}), do: "true"
  defp typed_default(%{type: "array"}), do: "[]"
  defp typed_default(%{type: "object"}), do: "%{}"
  defp typed_default(%{name: name}), do: "sample-#{name}" |> inspect_value()

  defp scenario_value(%Context{scenarios: [first | _]}, name) do
    get_in(first, ["when", "data", name])
  end

  defp scenario_value(_ctx, _name), do: nil

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
