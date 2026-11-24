defmodule Mix.Tasks.Sp.Gen.Endpoint do
  @shortdoc "Runs the generators of one operation's web actor, in build order"

  @moduledoc """
  The **endpoint suite**: the web actor of exactly one command or query.

  Tiers: blueprints render units; generators run blueprints; suites run
  generators. This suite resolves the operation's read model and runs, in
  build order:

  * `sp.gen.view` — the JSON:API view of the constituent's read model
  * `sp.gen.schema` — the OpenAPI request/response schemas
  * `sp.gen.controller` — controller action, route, endpoint tests
  * `sp.gen.bruno` — Bruno API documentation

      mix sp.gen.endpoint catalog-apparatus
      mix sp.gen.endpoint list-positions --dry-run

  Precondition: the domain operation exists and is green — the endpoint
  wraps its public API and nothing else. The operation always comes from
  the model; there is no `--template` here.

  The suite refuses until every member generator is ported to
  `sparch-elixir`, naming the missing ones. While it refuses, run the same
  sequence with the Elixir tool, in the order above.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:endpoint, argv)
end
