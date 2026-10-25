defmodule Sportipedia.Codegen.Unit do
  @moduledoc """
  One insertable chunk of code with an identity that can be checked against an
  existing file.

  The delta is **presence-based**: a unit is satisfied when the target file
  already contains it (identified by `check`), regardless of how the surrounding
  code was written. This is what keeps re-runs idempotent and human edits safe:

  * `check.(source)` — `true` when the unit is already present
  * `render.(ctx)` — the text to splice when it is not
  * `anchor.(source, ctx)` — where to splice (`{:before_line, n}` /
    `{:after_line, n}` / `:no_block`)
  * `gap` — `:blank` (surround with blank lines) or `:tight` (e.g. inside a
    `typedstruct` field list)
  """

  @enforce_keys [:id, :check, :render, :anchor]
  defstruct [:id, :check, :render, :anchor, :text_for, gap: :blank]

  @type source :: Sportipedia.Codegen.Source.t()
  @type ctx :: Sportipedia.Codegen.Context.t()
  @type t :: %__MODULE__{
          id: term(),
          check: (source() -> boolean()),
          render: (ctx() -> String.t()),
          # optional: source-dependent text (e.g. a route that must also
          # materialise its enclosing scopes); `nil` falls back to `render`
          text_for: (source(), ctx() -> String.t() | nil) | nil,
          anchor: (source(), ctx() -> Sportipedia.Codegen.Patch.Insertion.anchor() | :no_block),
          gap: :blank | :tight
        }

  @doc "Is this unit already present in `source`?"
  def present?(%__MODULE__{check: check}, source), do: check.(source)

  @doc "The insertion for this unit, or nil when present or un-anchorable."
  @spec insertion(t(), source(), ctx()) :: Sportipedia.Codegen.Patch.Insertion.t() | nil
  def insertion(%__MODULE__{} = unit, source, ctx) do
    if present?(unit, source) do
      nil
    else
      case unit.anchor.(source, ctx) do
        :no_block ->
          nil

        anchor ->
          %Sportipedia.Codegen.Patch.Insertion{
            anchor: anchor,
            text: text(unit, source, ctx),
            gap: unit.gap,
            id: unit.id
          }
      end
    end
  end

  defp text(%{text_for: nil, render: render}, _source, ctx), do: render.(ctx)

  defp text(%{text_for: fun, render: render}, source, ctx) do
    case fun.(source, ctx) do
      nil -> render.(ctx)
      text -> text
    end
  end
end
