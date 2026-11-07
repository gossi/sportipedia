defmodule Mix.Tasks.Sp.Gen.InternalApi do
  @shortdoc "Generates the internal API accessors for a constituent"

  @moduledoc """
  Generates the internal API of a constituent: `x_by_id/1` plus one accessor
  per unique-field invariant (`x_by_slug/1`).

  Executes `docs/architecture/blueprints/backend/domain/internal-api.md` and
  the `unique-slug` example (`SpGen.Blueprint.InternalAPI`).
  Internal API is used within the constituent (including tests) only —
  technical query implementations live in queries and validators, which call
  these accessors.

  The accessor's own dependencies are generated with it: the read model it
  reads and, per unique field, the `Queries.<DomainObject>By<Field>` lookup it
  delegates to (`SpGen.Blueprint.LookupQuery`). The same closure runs from
  `mix sp.gen.command`, since that is what needs a validator.

      mix sp.gen.internal_api read-model.apparatus

  Fixed shape — no `--template`.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:internal_api, argv)
end
