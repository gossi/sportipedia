defmodule Mix.Tasks.Sp.Gen.ReadModel do
  @shortdoc "Generates the shared read model with its changesets"

  @moduledoc """
  Generates the read-model citizen from the domain model.

  Executes `docs/architecture/blueprints/backend/domain/read-model.md`
  (`Sportipedia.Codegen.Blueprints.ReadModel`): the typed Ecto schema, the
  schema prefix and the `insert_changeset/2` / `update_changeset/2` pair.

      mix sp.gen.read_model read-model.apparatus

  Fixed shape — no `--template`. Migrations are out of scope: use
  `mix ecto.gen.migration` (the read model is the source for its table).
  """

  use Mix.Task

  alias Sportipedia.Codegen.{CLI, Blueprints}

  @impl Mix.Task
  def run(argv) do
    case CLI.run(Blueprints.ReadModel, argv) do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end
  end
end
