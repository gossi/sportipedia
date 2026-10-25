defmodule Mix.Tasks.Sp.Gen do
  @shortdoc "Lists the Sportipedia blueprint generators"

  @moduledoc """
  Lists every available `mix sp.gen.*` generator with the ESDM element kinds
  it consumes, the `--template` operations it renders, and the blueprint
  modules (generated files) it runs.

  These are the executable transfers of the blueprints in
  `docs/architecture/blueprints/`. Run one with an element address:

      mix sp.gen.command catalog-apparatus --template create
      mix sp.gen.event apparatus-cataloged --template create
      mix sp.gen.command_handler catalog-apparatus

  Every generator is idempotent: existing files only receive units that are
  missing (append-only AST merging), and `--check` reports drift without
  writing.
  """

  use Mix.Task

  alias Sportipedia.Codegen

  @impl Mix.Task
  def run(_argv) do
    shell = Mix.shell()
    shell.info("Sportipedia blueprint generators:\n")

    for {family, modules} <- Codegen.families() do
      primary = hd(modules)
      kinds = primary.source_kinds() |> Enum.map(&Atom.to_string/1) |> Enum.join(", ")

      templates =
        case primary.operations() do
          :fixed -> "fixed (no --template)"
          ops -> "--template " <> Enum.join(ops, " | ")
        end

      files = modules |> Enum.map(&short_name/1) |> Enum.join(", ")

      shell.info("  mix sp.gen.#{family} <element>")
      shell.info("    from: #{kinds}")
      shell.info("    #{templates}")
      shell.info("    blueprints: #{files}\n")
    end

    shell.info(Codegen.help())
  end

  defp short_name(module) do
    module |> Module.split() |> Enum.take(-2) |> Enum.join(".")
  end
end
