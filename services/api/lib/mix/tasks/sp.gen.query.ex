defmodule Mix.Tasks.Sp.Gen.Query do
  @shortdoc "Generates a query module for a query element"

  @moduledoc """
  Generates the query citizen from an ESDM **query** element:
  `import Ecto.Query` plus a `new/n` constructor.

  Executes `docs/architecture/blueprints/backend/domain/query.md`
  (`Sportipedia.Codegen.Blueprint.Query`). The concrete Ecto query depends on
  the feature specification — the blueprint's last 1% — so the body carries a
  stable `TODO:` marker.

      mix sp.gen.query read-apparatus
      mix sp.gen.query list-apparatuses

  Fixed shape — no `--template`.
  """

  use Mix.Task

  alias Sportipedia.Codegen.CLI

  @impl Mix.Task
  def run(argv) do
    case CLI.run(:query, argv) do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end
  end
end
