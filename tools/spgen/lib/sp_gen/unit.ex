defmodule SpGen.Unit do
  @moduledoc """
  One insertable chunk of code with an identity that can be checked against an
  existing file.

  The delta is **presence-based**: a unit is satisfied when the target file
  already contains it (identified by `check`), regardless of how the
  surrounding code was written. This keeps re-runs idempotent and human edits
  safe: present units are skipped, and the merge only appends AST nodes
  (`SpGen.Merge`) — it never rewrites existing code.

  Units are **reference-gated**: a unit whose code mentions another citizen
  (`requires`) is only placed while that citizen's file exists. Unmet
  references defer (reported, exit 0) and land later via the neighborhood
  closure of the run that creates the missing citizen — so generation order
  never matters and generated trees always compile.

  * `check.(source)` — `true` when the unit is already present
  * `render.(ctx)` — the Elixir source of the unit (parsed to AST at insert
    time; comments and doc blocks inside survive the round-trip)
  * `place.(ast, unit, ctx)` — where the parsed node lands, built by a
    `SpGen.Merge` factory
  * `requires.(ctx)` — `[{path, reason}]` that must exist on disk (or be
    created by the running generator) before this unit may be placed
  * `stale.(source, ctx)` — `[]`, or the details of a unit whose *line is
    present but does not carry everything the model states now*. Such a unit is
    never placed (appending a second line would silently shadow the first —
    `Vex.Struct.validates/2` keys validations by field) and is reported instead:
    the operator owns the edit, the tool owns the notice.
  """

  @enforce_keys [:id, :check, :render, :place]
  defstruct [
    :id,
    :check,
    :render,
    :place,
    requires: &SpGen.Unit.no_requires/1,
    stale: &SpGen.Unit.never_stale/2
  ]

  @doc "The default `requires` — a unit with no references is always placeable."
  def no_requires(_ctx), do: []

  @doc "The default `stale` — a unit that is present is complete."
  def never_stale(_source, _ctx), do: []

  @type source :: SpGen.Source.t()
  @type ctx :: SpGen.Context.t()
  @type t :: %__MODULE__{
          id: term(),
          check: (source() -> boolean()),
          render: (ctx() -> String.t()),
          place: SpGen.Merge.place(),
          requires: (ctx() -> [{String.t(), String.t()}]),
          stale: (source(), ctx() -> [String.t()])
        }

  @doc "Is this unit already present in `source`?"
  def present?(%__MODULE__{check: check}, source), do: check.(source)

  @doc """
  Details of a unit that is present in `source` but incomplete for `ctx` —
  `[]` when there is nothing to report.
  """
  @spec stale(t(), source(), ctx()) :: [String.t()]
  def stale(%__MODULE__{stale: stale}, source, ctx), do: stale.(source, ctx)

  @doc """
  Missing references of this unit for `ctx`: entries of `requires` whose path
  is not covered by `existing?.(path)`. `[]` means the unit is placeable.
  """
  @spec deferred(t(), ctx(), (String.t() -> boolean())) :: [{String.t(), String.t()}]
  def deferred(%__MODULE__{requires: requires}, ctx, existing?) do
    requires.(ctx) |> Enum.reject(fn {path, _reason} -> existing?.(path) end)
  end
end
