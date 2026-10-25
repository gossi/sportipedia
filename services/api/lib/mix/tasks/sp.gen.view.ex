defmodule Mix.Tasks.Sp.Gen.View do
  @shortdoc "Generates the JSON:API view for a read model"

  @moduledoc """
  Generates the JSON:API view citizen for an ESDM **read model** element,
  plus its own test file.

  Executes `docs/architecture/blueprints/backend/web/view.md`
  (`Sportipedia.Codegen.Blueprints.View`): `use JSONAPI.View` with the
  singular type, the resource `path/0` (`<subdomain>/<composite>/<domain-object>s`)
  and `fields/0` from the read model schema (id and timestamps are not
  attributes).

      mix sp.gen.view read-model.apparatus

  Fixed shape — no `--template`.
  """

  use Mix.Task

  alias Sportipedia.Codegen.{CLI, Blueprints}

  @impl Mix.Task
  def run(argv) do
    case CLI.run(Blueprints.View, argv) do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end
  end
end
