defmodule Mix.Tasks.Sp.Gen.ReadModel do
  @shortdoc "Generates the shared read model with its changesets"

  @moduledoc """
  Generates the read-model citizen from the domain model.

  Executes `docs/architecture/blueprints/backend/domain/read-model.md`
  (`SpGen.Blueprint.ReadModel`): the typed Ecto schema, the
  schema prefix and the `insert_changeset/2` / `update_changeset/2` pair.

      mix sp.gen.read_model read-model.apparatus

  Fixed shape — no `--template`. Migrations are out of scope: use
  `mix ecto.gen.migration` (the read model is the source for its table).
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:read_model, argv)
end
