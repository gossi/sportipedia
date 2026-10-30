defmodule Mix.Tasks.Sp.Gen.View do
  @shortdoc "Generates the JSON:API view for a read model"

  @moduledoc """
  Generates the JSON:API view citizen for an ESDM **read model** element,
  plus its own test file.

  Executes `docs/architecture/blueprints/backend/web/view.md`
  (`SpGen.Blueprint.View`): `use JSONAPI.View` with the
  singular type, the resource `path/0` (`<subdomain>/<composite>/<domain-object>s`)
  and `fields/0` from the read model schema (id and timestamps are not
  attributes).

      mix sp.gen.view read-model.apparatus

  Fixed shape — no `--template`.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:view, argv)
end
