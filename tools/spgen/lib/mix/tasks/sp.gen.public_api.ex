defmodule Mix.Tasks.Sp.Gen.PublicApi do
  @shortdoc "Generates the public API function for an operation"

  @moduledoc """
  Generates the public-API port function for one ESDM operation (the
  constituent port — exactly one function per operation).

  Executes `docs/architecture/blueprints/backend/domain/public-api.md`
  (`SpGen.Blueprint.PublicAPI`): `@doc`, `@spec`
  (`Architecture.public_api/...`) and the function body per operation —
  commands dispatch with `consistency: :strong` (create generates the id) and
  classify validation failures; a read goes through the internal API; a
  collection reads through the query citizen, which owns the JSON:API
  translation (a run of this generator creates that query with it).

      mix sp.gen.public_api catalog-apparatus --template create
      mix sp.gen.public_api read-apparatus --template read
      mix sp.gen.public_api list-apparatuses --template collection

  Adds the matching `Public API - <operation>` `describe` block to the
  operation test.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:public_api, argv)
end
