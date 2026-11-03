defmodule Mix.Tasks.Sp.Gen.Controller do
  @shortdoc "Generates the controller action, endpoint test and route"

  @moduledoc """
  Generates the web controller action for one ESDM operation (command or
  query), its endpoint test file, and the route registration in the web
  router's scope chain (`/<subdomain> → /<composite> → /<domain-object>s`).

  Executes `docs/architecture/blueprints/backend/web/controller.md` plus the
  paired `endpoint-test.md` (`SpGen.Blueprint.Controller`).
  Only `GET` (queries) and `POST` (commands) — every write is a command
  endpoint. The endpoint tests follow the blueprint's status matrix (create
  200/422/403, delete 204/404/403, read 200/404, collection 200).

      mix sp.gen.controller catalog-apparatus --template create
      mix sp.gen.controller read-apparatus --template read
      mix sp.gen.controller list-apparatuses --template collection
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:controller, argv)
end
