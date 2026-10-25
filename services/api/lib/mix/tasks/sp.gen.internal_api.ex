defmodule Mix.Tasks.Sp.Gen.InternalApi do
  @shortdoc "Generates the internal API accessors for a constituent"

  @moduledoc """
  Generates the internal API of a constituent: `x_by_id/1` plus one accessor
  per unique-field invariant (`x_by_slug/1`).

  Executes `docs/architecture/blueprints/backend/domain/internal-api.md` and
  the `unique-slug` example (`Sportipedia.Codegen.Blueprints.InternalAPI`).
  Internal API is used within the constituent (including tests) only —
  technical query implementations live in queries and validators, which call
  these accessors.

      mix sp.gen.internal_api read-model.apparatus

  Fixed shape — no `--template`.
  """

  use Mix.Task

  alias Sportipedia.Codegen.{CLI, Blueprints}

  @impl Mix.Task
  def run(argv) do
    case CLI.run(Blueprints.InternalAPI, argv) do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end
  end
end
