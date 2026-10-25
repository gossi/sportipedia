defmodule Mix.Tasks.Sp.Gen.Controller do
  @shortdoc "Generates the controller action, endpoint test and route"

  @moduledoc """
  Generates the web controller action for one ESDM operation (command or
  query), its endpoint test file, and the route registration in the web
  router's scope chain (`/<subdomain> → /<composite> → /<domain-object>s`).

  Executes `docs/architecture/blueprints/backend/web/controller.md` plus the
  paired `endpoint-test.md` (`Sportipedia.Codegen.Blueprints.Controller`).
  Only `GET` (queries) and `POST` (commands) — every write is a command
  endpoint. The endpoint tests follow the blueprint's status matrix (create
  200/422/403, delete 204/404/403, read 200/404, collection 200).

      mix sp.gen.controller catalog-apparatus --template create
      mix sp.gen.controller read-apparatus --template read
      mix sp.gen.controller list-apparatuses --template collection
  """

  use Mix.Task

  alias Sportipedia.Codegen.{CLI, Blueprints}

  @impl Mix.Task
  def run(argv) do
    case CLI.run(Blueprints.Controller, argv) do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end
  end
end
