defmodule Mix.Tasks.Sp.Gen.Query do
  @shortdoc "Generates a query module for a query element"

  @moduledoc """
  Generates the query citizen from an ESDM **query** element:
  `import Ecto.Query` plus a `new/n` constructor.

  Executes `docs/architecture/blueprints/backend/domain/query.md`
  (`SpGen.Blueprint.Query`). The concrete Ecto query depends on
  the feature specification — the blueprint's last 1% — so the body carries a
  stable `TODO:` marker.

      mix sp.gen.query read-apparatus
      mix sp.gen.query list-apparatuses

  Fixed shape — no `--template`.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:query, argv)
end
