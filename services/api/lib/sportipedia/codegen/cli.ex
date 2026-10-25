defmodule Sportipedia.Codegen.CLI do
  @moduledoc """
  Report formatting and exit semantics for the `mix sp.gen.*` tasks.

  Prints one line per file the generator touched, and turns problems (usage
  errors, units with no place in an existing file, missing registration
  files) into `{:error, message}` so the task can `Mix.raise/1`.
  """

  alias Sportipedia.Codegen

  @doc "Runs family `family` against `argv`, reports, returns `:ok | {:error, msg}`."
  @spec run(atom(), [String.t()]) :: :ok | {:error, String.t()}
  def run(family, argv) do
    task = "sp.gen.#{family}"

    case Codegen.run(family, argv) do
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

  defp print(results) do
    shell = Mix.shell()

    for result <- results do
      shell.info(format(result))
    end
  end

  @doc false
  def format({:created, path}), do: "created   #{path}"

  def format({:merged, path, ids}) do
    "merged    #{path} (#{Enum.map_join(ids, ", ", &inspect/1)})"
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
