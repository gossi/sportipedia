defmodule Mix.Tasks.Sp.Gen do
  @shortdoc "Lists the Sportipedia blueprint generators"

  @moduledoc """
  Lists every available `mix sp.gen.*` generator with the ESDM element kinds
  it consumes and the `--template` operations it renders.

  These are the executable transfers of the blueprints in
  `docs/architecture/blueprints/`. Run one with an element address:

      mix sp.gen.command catalog-apparatus --template create
      mix sp.gen.event apparatus-cataloged --template create
      mix sp.gen.command_handler catalog-apparatus

  Every generator is idempotent: existing files only receive units that are
  missing, and `--check` reports drift without writing.
  """

  use Mix.Task

  alias Sportipedia.Codegen

  @impl Mix.Task
  def run(_argv) do
    shell = Mix.shell()
    shell.info("Sportipedia blueprint generators:\n")

    for {_name, blueprint} <- Codegen.blueprints() do
      kinds = blueprint.source_kinds() |> Enum.map(&Atom.to_string/1) |> Enum.join(", ")

      templates =
        case blueprint.operations() do
          :fixed -> "fixed (no --template)"
          ops -> "--template " <> Enum.join(ops, " | ")
        end

      shell.info("  mix #{blueprint.task()} <element>")
      shell.info("    from: #{kinds}")
      shell.info("    #{templates}\n")
    end

    shell.info(Codegen.help())
  end
end
