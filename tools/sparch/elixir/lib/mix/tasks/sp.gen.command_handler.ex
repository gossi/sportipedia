defmodule Mix.Tasks.Sp.Gen.CommandHandler do
  @shortdoc "Generates a command handler module and its test describe block"

  @moduledoc """
  Generates the command handler citizen from an ESDM command element.

  Runs one command's handler:

  * `services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/operations/<_operation>/handler.ex`
  * the `<Command>Handler` `describe` block in the operation test file

  The handler shape is fixed (input command, output events) — this generator
  takes no `--template`:

      mix sp.gen.command_handler command.catalog-apparatus
      mix sp.gen.command_handler esdm:domain=sport/bounded-context=sport/aggregate=apparatus/command=edit-apparatus

  The `dispatch` registration lives with the command blueprint
  (`mix sp.gen.command`). Idempotent: an existing handler only receives
  missing units.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:command_handler, argv)
end
