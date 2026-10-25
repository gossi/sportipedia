defmodule Mix.Tasks.Sp.Gen.Projector do
  @shortdoc "Generates a projector clause for an event and registers the projector"

  @moduledoc """
  Generates the projector citizen from an ESDM event element.

  Executes `docs/architecture/blueprints/backend/domain/projector.md`
  (`Sportipedia.Codegen.Blueprint.Projector`): the constituent projector's
  `project` clause for the event (insert / update / delete per its read-model
  projection rule) plus registration in the nearest supervisor, and the
  `<Projector> - <Event>` `describe` block in the publishing command's
  operation test.

      mix sp.gen.projector apparatus-cataloged --template create

  `--template` (create | update | delete) overrides the effect derived from
  the read model's projection rule.
  """

  use Mix.Task

  alias Sportipedia.Codegen.CLI

  @impl Mix.Task
  def run(argv) do
    case CLI.run(:projector, argv) do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end
  end
end
