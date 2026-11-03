defmodule Mix.Tasks.Sp.Gen.Command do
  @shortdoc "Generates a command module, its test and router registration"

  @moduledoc """
  Generates the command citizen from an ESDM command element.

  Executes the blueprint `docs/architecture/blueprints/backend/domain/command.md`
  (transferred to `SpGen.Blueprint.Command`):

  * `services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>/command.ex`
  * the `<Command> command` `describe` block in the operation test file
  * registration in the composite's commanded router (`identify`/`dispatch`),
    and that router with the subdomain's commanded application (`router …`) —
    both files are created here when the composite or subdomain lacks one

  The command struct is created for what the operation does:

      mix sp.gen.command command.catalog-apparatus --template create
      mix sp.gen.command esdm:domain=sport/bounded-context=sport/aggregate=apparatus/command=edit-apparatus --template update
      mix sp.gen.command archive-apparatus --template delete

  See `SpGen.help/0` for all options (`--subdomain`,
  `--composite`, `--constituent`, `--check`, ...).

  Idempotent: existing files only receive units (module, `use`s, aliases,
  `field`s, `validates`, `middleware`, `identify`/`dispatch` entries,
  `describe`) that are missing; running the task twice changes nothing.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: Mix.Tasks.Sp.Gen.delegate(:command, argv)
end
