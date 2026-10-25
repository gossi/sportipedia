defmodule Mix.Tasks.Sp.Gen.PublicApi do
  @shortdoc "Generates the public API function for an operation"

  @moduledoc """
  Generates the public-API port function for one ESDM operation (the
  constituent port — exactly one function per operation).

  Executes `docs/architecture/blueprints/backend/domain/public-api.md`
  (`Sportipedia.Codegen.Blueprint.PublicAPI`): `@doc`, `@spec`
  (`Architecture.public_api/...`) and the function body per operation —
  commands dispatch with `consistency: :strong` (create generates the id) and
  classify validation failures; queries read through the internal API /
  `Repo` + JSON:API `QueryBuilder`.

      mix sp.gen.public_api catalog-apparatus --template create
      mix sp.gen.public_api read-apparatus --template read
      mix sp.gen.public_api list-apparatuses --template collection

  Adds the matching `Public API - <operation>` `describe` block to the
  operation test.
  """

  use Mix.Task

  alias Sportipedia.Codegen.CLI

  @impl Mix.Task
  def run(argv) do
    case CLI.run(:public_api, argv) do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end
  end
end
