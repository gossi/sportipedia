defmodule SpGen.Formatter do
  @moduledoc """
  Canonical formatting for generated code, equal to what `mix format` applies
  to the project.

  `Code.format_string!/2` needs the same `locals_without_parens` the project's
  `.formatter.exs` resolves — including the ones imported from deps
  (`import_deps`). Those are computed once per cwd and cached: a dep exports
  its locals through `export: [locals_without_parens: ...]` in its own
  `.formatter.exs`; the project file carries them at the top level.

  The configuration is read through a `SpGen.FS` handle, so a run against an
  in-memory repository formats exactly like a run against the disk.
  """

  alias SpGen.FS

  @doc """
  Formatter options equivalent to the project's `mix format`, read from `cwd`
  through `fs`.
  """
  @spec opts(Path.t(), FS.t()) :: keyword()
  def opts(cwd \\ File.cwd!(), fs \\ FS.default()) do
    config = eval_formatter(cwd, ".formatter.exs", fs)

    locals =
      Keyword.get(config, :locals_without_parens, []) ++
        deps_locals(cwd, fs, Keyword.get(config, :import_deps, []), MapSet.new())

    [locals_without_parens: Enum.uniq(locals)]
  end

  @doc "Format source text the way the project formatter would (binary result)."
  @spec format(String.t(), keyword()) :: String.t()
  def format(text, opts) do
    text |> Code.format_string!(opts) |> IO.iodata_to_binary()
  end

  defp deps_locals(_cwd, _fs, [], _visited), do: []

  defp deps_locals(cwd, fs, deps, visited) do
    {new_locals, new_visited} =
      Enum.reduce(deps, {[], visited}, fn dep, {acc, seen} ->
        if MapSet.member?(seen, dep) do
          {acc, seen}
        else
          file = Path.join([cwd, "deps", to_string(dep), ".formatter.exs"])

          case eval_file_if_exists(file, fs) do
            nil ->
              {acc, MapSet.put(seen, dep)}

            config ->
              exported =
                Keyword.get(config, :export, []) |> Keyword.get(:locals_without_parens, [])

              own = Keyword.get(config, :locals_without_parens, [])

              nested =
                deps_locals(cwd, fs, Keyword.get(config, :import_deps, []), MapSet.put(seen, dep))

              {acc ++ exported ++ own ++ nested, MapSet.put(seen, dep)}
          end
        end
      end)

    new_locals ++ deps_locals(cwd, fs, [], new_visited)
  end

  defp eval_formatter(cwd, name, fs) do
    case eval_file_if_exists(Path.join(cwd, name), fs) do
      nil -> []
      config -> config
    end
  end

  defp eval_file_if_exists(path, fs) do
    with true <- FS.exists?(fs, path),
         {:ok, text} <- FS.read(fs, path) do
      {config, _} = Code.eval_string(text, [], file: path)
      config
    else
      _ -> nil
    end
  end
end
