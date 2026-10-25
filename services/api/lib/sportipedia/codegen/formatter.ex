defmodule Sportipedia.Codegen.Formatter do
  @moduledoc """
  Canonical formatting for generated code, equal to what `mix format` applies
  to the project.

  `Code.format_string!/2` needs the same `locals_without_parens` the project's
  `.formatter.exs` resolves — including the ones imported from deps
  (`import_deps`). Those are computed once per cwd and cached: a dep exports
  its locals through `export: [locals_without_parens: ...]` in its own
  `.formatter.exs`; the project file carries them at the top level.
  """

  @doc "Formatter options equivalent to the project's `mix format`."
  @spec opts(Path.t()) :: keyword()
  def opts(cwd \\ File.cwd!()) do
    config = eval_formatter(cwd, ".formatter.exs")

    locals =
      Keyword.get(config, :locals_without_parens, []) ++
        deps_locals(cwd, Keyword.get(config, :import_deps, []), MapSet.new())

    [locals_without_parens: Enum.uniq(locals)]
  end

  @doc "Format source text the way the project formatter would (binary result)."
  @spec format(String.t(), keyword()) :: String.t()
  def format(text, opts) do
    text |> Code.format_string!(opts) |> IO.iodata_to_binary()
  end

  @spec format(String.t(), Path.t(), keyword()) :: String.t()
  def format(text, cwd, _env) when is_binary(cwd) do
    format(text, opts(cwd))
  end

  defp deps_locals(_cwd, [], _visited), do: []

  defp deps_locals(cwd, deps, visited) do
    {new_locals, new_visited} =
      Enum.reduce(deps, {[], visited}, fn dep, {acc, seen} ->
        if MapSet.member?(seen, dep) do
          {acc, seen}
        else
          file = Path.join([cwd, "deps", to_string(dep), ".formatter.exs"])

          case eval_file_if_exists(file) do
            nil ->
              {acc, MapSet.put(seen, dep)}

            config ->
              exported =
                Keyword.get(config, :export, []) |> Keyword.get(:locals_without_parens, [])

              own = Keyword.get(config, :locals_without_parens, [])

              nested =
                deps_locals(cwd, Keyword.get(config, :import_deps, []), MapSet.put(seen, dep))

              {acc ++ exported ++ own ++ nested, MapSet.put(seen, dep)}
          end
        end
      end)

    new_locals ++ deps_locals(cwd, [], new_visited)
  end

  defp eval_formatter(cwd, name) do
    case eval_file_if_exists(Path.join(cwd, name)) do
      nil -> []
      config -> config
    end
  end

  defp eval_file_if_exists(path) do
    if File.exists?(path) do
      {config, _} = Code.eval_file(path)
      config
    end
  end
end
