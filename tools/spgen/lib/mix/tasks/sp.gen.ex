defmodule Mix.Tasks.Sp.Gen do
  @shortdoc "Lists the Sportipedia blueprint generators"

  @moduledoc """
  The one supported entry point to the blueprint generators.

  This task (and its `mix sp.gen.<generator>` siblings) delegates to the
  `spgen` escript built from the `tools/spgen` Mix project — the executable
  transfers of the blueprints in `docs/architecture/blueprints/`. The
  executable is built automatically when missing or older than the tool's
  sources (`SPGEN_NO_AUTOBUILD=1` opts out).

      mix sp.gen                                            # list generators
      mix sp.gen.command catalog-apparatus --template create
      mix sp.gen.aggregate widget --check

  These task modules live in the generator project, and the API depends on it
  (`{:spgen, path: "../../tools/spgen", runtime: false, only: [:dev, :test]}`).
  That placement is deliberate: Mix resolves a dependency's tasks without
  compiling the host project first, so a generator can repair a tree that does
  not compile — e.g. one whose event file was deleted while its aggregate still
  matches on its struct. Tasks defined inside the API would have had to compile
  it first, and that is exactly the state the generator is called to fix.

  The generators are also idempotent and append-only, so the tree keeps
  compiling after every run (references to not-yet-generated citizens stay
  deferred), and the same binary works standalone from anywhere in the repo:

      tools/spgen/spgen <generator> <element> [options]
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: exec(argv)

  @doc false
  @spec delegate(atom(), [String.t()]) :: :ok
  def delegate(generator, argv), do: exec([Atom.to_string(generator) | argv])

  defp exec(args) do
    bin = executable()
    {_out, status} = System.cmd(bin, args, into: IO.stream(:stdio, :line))

    if status != 0, do: Mix.raise("spgen exited with status #{status}")

    :ok
  end

  # The repo root is found by walking up from the host project's `mix.exs`
  # (these tasks are a dependency of the API app) to the directory that holds
  # both the generators and the domain model, so the layout is verified rather
  # than assumed from a fixed number of `..`s.
  defp repo_root do
    start =
      case Mix.Project.project_file() do
        nil -> Mix.raise("sp.gen tasks must run inside a Mix project")
        mix_exs -> Path.dirname(mix_exs)
      end

    walk_to_repo_root(start) ||
      Mix.raise(
        "could not find the Sportipedia repo from #{start} — expected a directory holding docs/domain-model"
      )
  end

  defp walk_to_repo_root("/" <> _ = dir) do
    cond do
      repo_root?(dir) -> dir
      dir == "/" -> nil
      true -> walk_to_repo_root(Path.dirname(dir))
    end
  end

  defp walk_to_repo_root(_), do: nil

  defp repo_root?(dir) do
    File.dir?(Path.join(dir, "docs/domain-model")) and
      File.dir?(Path.join(dir, "tools/spgen"))
  end

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
