defmodule SpGen.Unit do
  @moduledoc """
  One insertable chunk of code with an identity that can be checked against an
  existing file.

  The delta is **presence-based**: a unit is satisfied when the target file
  already contains it (identified by `check`), regardless of how the
  surrounding code was written. This keeps re-runs idempotent and human edits
  safe: present units are skipped, and the merge only appends AST nodes
  (`SpGen.Merge`) — it never rewrites existing code.

  * `check.(source)` — `true` when the unit is already present
  * `render.(ctx)` — the Elixir source of the unit (parsed to AST at insert
    time; comments and doc blocks inside survive the round-trip)
  * `place.(ast, unit, ctx)` — where the parsed node lands, built by a
    `SpGen.Merge` factory
  """

  @enforce_keys [:id, :check, :render, :place]
  defstruct [:id, :check, :render, :place]

  @type source :: SpGen.Source.t()
  @type ctx :: SpGen.Context.t()
  @type t :: %__MODULE__{
          id: term(),
          check: (source() -> boolean()),
          render: (ctx() -> String.t()),
          place: SpGen.Merge.place()
        }

  @doc "Is this unit already present in `source`?"
  def present?(%__MODULE__{check: check}, source), do: check.(source)
end
