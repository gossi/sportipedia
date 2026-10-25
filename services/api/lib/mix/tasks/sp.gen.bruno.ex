defmodule Mix.Tasks.Sp.Gen.Bruno do
  @shortdoc "Generates the Bruno API-request documentation for an operation"

  @moduledoc """
  Generates the Bruno collection documentation for one ESDM operation
  (command or query), plus the constituent's `folder.yml`.

  Executes `docs/architecture/blueprints/backend/web/bruno.md`
  (`Sportipedia.Codegen.Blueprints.Bruno`):

  * `bruno/<Subdomain>/<Composite>/<Constituent>/<Operation Title>.yml`
  * JSON:API bodies mirroring the operation data (`create` carries attributes
    only, `update`/`delete` address the row by `id`)
  * `examples:` generated from the domain model's feature scenarios
  * `{{apiUrl}}` references the collection variables (`bruno/environments/`)

      mix sp.gen.bruno catalog-apparatus
      mix sp.gen.bruno read-apparatus
      mix sp.gen.bruno list-apparatuses

  Docs artifacts are create-only: existing files are never rewritten, so
  hand-tuned responses and extra examples survive every run. Run the command
  operations before the query ones so `seq:` keeps commands first.
  """

  use Mix.Task

  alias Sportipedia.Codegen.{CLI, Blueprints}

  @impl Mix.Task
  def run(argv) do
    case CLI.run(Blueprints.Bruno, argv) do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end
  end
end
