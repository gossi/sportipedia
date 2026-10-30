defmodule SpGen.CLI do
  @moduledoc """
  Escript entry point (`tools/spgen/spgen`) and report formatting.

  Usage — mirrors the `mix sp.gen.*` tasks, which delegate here:

      spgen                       # list all generator families
      spgen <family> <element> [options]

  Prints one line per file the generator touched, and turns problems (usage
  errors, units with no place in an existing file, missing registration
  files) into exit status 1; deferred units are reported and exit 0.
  """

  alias SpGen

  @doc "Escript entry; `System.halt(1)`s on hard errors."
  def main(argv) do
    # the BEAM booted by an escript starts no applications
    Application.ensure_all_started(:yaml_elixir)

    case argv do
      [] ->
        list_families()

      ["--help"] ->
        list_families()
        IO.puts(SpGen.help())

      [family | rest] ->
        case to_family(family) do
          nil ->
            die("unknown generator family: #{family}\n\nRun `spgen` to list families.")

          atom ->
            case run(atom, rest) do
              :ok -> :ok
              {:error, message} -> die(message)
            end
        end
    end
  end

  @doc "Runs family `family` against `argv`, reports, returns `:ok | {:error, msg}`."
  @spec run(atom(), [String.t()]) :: :ok | {:error, String.t()}
  def run(family, argv) do
    task = "sp.gen.#{family}"

    case SpGen.run(family, argv) do
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

  @doc "The families listing (also what bare `spgen` prints)."
  def list_families do
    IO.puts("Sportipedia blueprint generators:\n")

    for {family, modules} <- SpGen.families() do
      primary = hd(modules)
      kinds = primary.source_kinds() |> Enum.map(&Atom.to_string/1) |> Enum.join(", ")

      templates =
        case primary.operations() do
          :fixed -> "fixed (no --template)"
          ops -> "--template " <> Enum.join(ops, " | ")
        end

      files = modules |> Enum.map(&short_name/1) |> Enum.join(", ")

      IO.puts("  spgen #{family} <element>")
      IO.puts("    from: #{kinds}")
      IO.puts("    #{templates}")
      IO.puts("    blueprints: #{files}\n")
    end

    IO.puts(SpGen.help())
  end

  defp to_family(name) do
    Enum.find(SpGen.families() |> Map.keys(), &(&1 |> Atom.to_string() == name))
  end

  defp short_name(module) do
    module |> Module.split() |> Enum.take(-2) |> Enum.join(".")
  end

  defp print(results) do
    for result <- results, do: IO.puts(format(result))
  end

  defp die(message) do
    IO.puts(:stderr, "error: " <> message)
    System.halt(1)
  end

  @doc false
  def format({:created, path}), do: "created   #{path}"

  def format({:merged, path, ids}) do
    "merged    #{path} (#{Enum.map_join(ids, ", ", &inspect/1)})"
  end

  def format({:backfill, path, ids}) do
    "backfill  #{path} (#{Enum.map_join(ids, ", ", &inspect/1)})"
  end

  def format({:deferred, path, entries}) do
    "deferred  #{path} — " <>
      Enum.map_join(Enum.uniq_by(entries, &elem(&1, 0)), "; ", fn {id, reason} ->
        "#{inspect(id)}: #{reason}"
      end)
  end

  def format({:unchanged, path}), do: "unchanged #{path}"

  def format({:checked, path, ids}) do
    "would add #{path} (#{Enum.map_join(ids, ", ", &inspect/1)})"
  end

  def format({:blocked, path, ids}) do
    "BLOCKED   #{path} — no place for #{Enum.map_join(ids, ", ", &inspect/1)}"
  end

  def format({:error, path, reason}), do: "ERROR     #{path} — #{inspect(reason)}"
  def format(other), do: inspect(other)
end
