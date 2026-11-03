defmodule SpGen.CLI do
  @moduledoc """
  Escript entry point (`tools/spgen/spgen`) and report formatting.

  Usage — mirrors the `mix sp.gen.*` tasks, which delegate here.
  Bare element names resolve among the kinds the generator produces.

      spgen                       # list all generators
      spgen <generator> <element> [options]

  Prints the run's report grouped by what happened (`Created`, `Updated`,
  `Ignored`, plus `Blocked` / `Failed` when they apply — see
  `SpGen.Report`), and turns problems (usage errors, units with no place in
  an existing file, missing registration files) into exit status 1; deferred
  units are reported and exit 0.
  """

  alias SpGen

  @doc "Escript entry; `System.halt(1)`s on hard errors."
  def main(argv) do
    # the BEAM booted by an escript starts no applications
    Application.ensure_all_started(:yaml_elixir)

    case argv do
      [] ->
        list_generators()

      ["--help"] ->
        list_generators()
        IO.puts(SpGen.help())

      [generator | rest] ->
        case to_generator(generator) do
          nil ->
            die("unknown generator: #{generator}\n\nRun `spgen` to list generators.")

          atom ->
            case run(atom, rest) do
              :ok -> :ok
              {:error, message} -> die(message)
            end
        end
    end
  end

  @doc "Runs generator `generator` against `argv`, reports, returns `:ok | {:error, msg}`."
  @spec run(atom(), [String.t()]) :: :ok | {:error, String.t()}
  def run(generator, argv) do
    task = "sp.gen.#{generator}"

    case SpGen.run(generator, argv) do
      {:error, message} ->
        {:error, message}

      {:ok, results} ->
        print(results)
        failures = Enum.filter(results, &match?({:error, _, _}, &1))
        blocked = Enum.filter(results, &match?({:blocked, _, _}, &1))

        cond do
          failures != [] ->
            {:error,
             "#{task} could not complete — " <>
               Enum.map_join(failures, "; ", fn {:error, path, reason} ->
                 "#{path}: #{inspect(reason)}"
               end)}

          blocked != [] ->
            {:error,
             "#{task} found units it cannot place — " <>
               Enum.map_join(blocked, "; ", fn {:blocked, path, ids} ->
                 "#{path}: #{inspect(ids)}"
               end)}

          true ->
            :ok
        end
    end
  end

  @doc "Print the grouped generator listing and the shared help text."
  def list_generators do
    IO.puts(Enum.join(generators_listing(), "\n"))
    IO.puts(SpGen.help())
  end

  @doc """
  The generator listing as lines (what bare `spgen` prints), grouped by the
  actor each generator serves — Domain first, then Web — each group in the
  order the generators are meant to run in.
  """
  @spec generators_listing() :: [String.t()]
  def generators_listing do
    header = ["Sportipedia blueprint generators:", ""]
    header ++ Enum.flat_map(SpGen.generators_by_actor(), &section/1)
  end

  defp section({actor, generators}) do
    [actor_label(actor) | Enum.flat_map(generators, &generator_lines/1)]
  end

  defp actor_label(actor), do: actor |> Atom.to_string() |> String.capitalize()

  defp generator_lines(generator) do
    modules = SpGen.generators()[generator]
    primary = hd(modules)
    kinds = primary.source_kinds() |> Enum.map(&Atom.to_string/1) |> Enum.join(", ")

    templates =
      case primary.operations() do
        :fixed -> "fixed (no --template)"
        ops -> "--template " <> Enum.join(ops, " | ")
      end

    files = modules |> Enum.map(&short_name/1) |> Enum.join(", ")

    [
      "  spgen #{generator} <element>",
      "    from: #{kinds}",
      "    #{templates}",
      "    blueprints: #{files}",
      ""
    ]
  end

  defp to_generator(name) do
    Enum.find(SpGen.generators() |> Map.keys(), &(&1 |> Atom.to_string() == name))
  end

  defp short_name(module) do
    module |> Module.split() |> Enum.take(-2) |> Enum.join(".")
  end

  defp print(results) do
    results
    |> SpGen.Report.render()
    |> Enum.each(&IO.puts/1)
  end

  defp die(message) do
    IO.puts(:stderr, "error: " <> message)
    System.halt(1)
  end
end
