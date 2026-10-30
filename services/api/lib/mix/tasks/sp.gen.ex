defmodule Mix.Tasks.Sp.Gen do
  @shortdoc "Lists the Sportipedia blueprint generators"

  @moduledoc """
  The one supported entry point to the blueprint generators.

  This task (and its `mix sp.gen.<family>` siblings) delegates to the
  `spgen` escript built from the `tools/spgen` Mix project — the executable
  transfers of the blueprints in `docs/architecture/blueprints/`. The
  executable is built automatically when missing or older than the tool's
  sources (`SPGEN_NO_AUTOBUILD=1` opts out).

      mix sp.gen                                            # list families
      mix sp.gen.command catalog-apparatus --template create
      mix sp.gen.aggregate widget --check

  Because the generators live outside this app, running them never requires
  the generated tree to compile — and the tree keeps compiling after every
  run by construction (references to not-yet-generated citizens stay
  deferred). Recovery hatch if the project itself is broken: run the binary
  directly, `tools/spgen/spgen <family> <element> [options]`.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: exec(argv)

  @doc false
  @spec delegate(atom(), [String.t()]) :: :ok
  def delegate(family, argv), do: exec([Atom.to_string(family) | argv])

  defp exec(args) do
    bin = executable()
    {_out, status} = System.cmd(bin, args, into: IO.stream(:stdio, :line))

    if status != 0, do: Mix.raise("spgen exited with status #{status}")

    :ok
  end

  # <repo>/services/api/lib/mix/tasks → up five = repo root
  defp repo_root, do: Path.expand("../../../../..", __DIR__)

  defp executable do
    root = repo_root()
    bin = Path.join(root, "tools/spgen/spgen")
    tool = Path.join(root, "tools/spgen")

    unless File.exists?(bin) do
      if autobuild?() do
        build(tool)
      else
        Mix.raise("spgen missing at #{bin} — run `mix escript.build` in tools/spgen")
      end
    end

    if autobuild?() && File.exists?(bin) && stale?(tool, bin), do: build(tool)
    bin
  end

  defp autobuild?, do: System.get_env("SPGEN_NO_AUTOBUILD") in [nil, ""]

  defp stale?(tool, bin) do
    bin_mtime = File.stat!(bin).mtime

    sources(tool)
    |> Enum.any?(fn path ->
      case File.stat(path) do
        {:ok, %{mtime: m}} -> m > bin_mtime
        _ -> false
      end
    end)
  end

  defp sources(tool) do
    Path.wildcard(Path.join(tool, "lib/**/*.ex")) ++
      [Path.join(tool, "mix.exs"), Path.join(tool, "mix.lock")]
  end

  defp build(tool) do
    Mix.shell().info("(building spgen…)")

    with {out, 0} <- System.cmd("mix", ["deps.get"], cd: tool, stderr_to_stdout: true),
         _ <- out,
         {out, 0} <- System.cmd("mix", ["escript.build"], cd: tool, stderr_to_stdout: true) do
      _ = out
      :ok
    else
      {out, status} ->
        Mix.raise("building spgen failed (status #{status}):\n#{out}")
    end
  end
end
