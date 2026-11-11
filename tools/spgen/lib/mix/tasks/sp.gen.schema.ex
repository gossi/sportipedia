defmodule Mix.Tasks.Sp.Gen.Schema do
  @shortdoc "Generates OpenAPI schemas documenting an endpoint"

  @moduledoc """
  Generates the OpenAPI schema citizens (plus their ExUnit test files) that
  document an endpoint, driven by the element kind.

  Executes `docs/architecture/blueprints/backend/web/schema.md`
  (`SpGen.Blueprint.Schema`):

  * read model → `<DomainObject>Response` + `<DomainObject>CollectionResponse`
  * command (`create`/`update`) → `<Command>Request` (`delete` carries none)
  * query (collection) → `<Operation>QueryParams`

  Both JSON:API halves are derived from the view — `OpenApiSchema.from_view/2`
  for the response, `OpenApiSchema.query_params/2` for the request parameters
  the model declares filterable and sortable — so no schema file transcribes a
  field list the controller already validates.

      mix sp.gen.schema read-model.apparatus
      mix sp.gen.schema catalog-apparatus --template create
      mix sp.gen.schema list-apparatuses --template collection
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:schema, argv)
end
