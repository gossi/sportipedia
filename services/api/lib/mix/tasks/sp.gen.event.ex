defmodule Mix.Tasks.Sp.Gen.Event do
  @shortdoc "Generates an event module and its test describe block"

  @moduledoc """
  Generates the event citizen from an ESDM event element.

  Executes the blueprint `docs/architecture/blueprints/backend/domain/event.md`
  (transferred to `Sportipedia.Codegen.Blueprint.Event`):

  * `services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/events/<_event>.ex`
  * the `<Event> event` `describe` block in the operation test file(s) of the
    command(s) publishing it

  Templates follow the operation:

      mix sp.gen.event apparatus-cataloged --template create   # full facts
      mix sp.gen.event apparatus-edited --template update      # partial + get_changes/1
      mix sp.gen.event apparatus-archived --template delete    # id-only

  Idempotent: an existing event file only receives missing units.
  """

  use Mix.Task

  alias Sportipedia.Codegen.CLI

  @impl Mix.Task
  def run(argv) do
    case CLI.run(:event, argv) do
      :ok ->
        :ok

      {:error, message} ->
        Mix.raise(message)
    end
  end
end
