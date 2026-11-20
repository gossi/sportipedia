defmodule Mix.Tasks.Sp.Gen do
  @shortdoc "Lists the Sportipedia blueprint generators"

  @moduledoc """
  The one supported entry point to the BE blueprint generators.

  This task (and its `mix sp.gen.<generator>` siblings) delegates to the
  `spgen-elixir` binary built from the Rust workspace one directory up —
  the executable transfers of the blueprints in
  `docs/architecture/blueprints/backend/`. The binary is built
  automatically when missing or older than the crate sources
  (`SPGEN_NO_AUTOBUILD=1` opts out).

  Tiers: blueprints render units; generators run blueprints; suites run
  generators.

      mix sp.gen                                            # list generators and suites
      mix sp.gen.command catalog-apparatus --template create
      mix sp.gen.read_model widget --dry-run
      mix sp.gen.operation catalog-apparatus                # suite: one operation, domain actor
      mix sp.gen.endpoint catalog-apparatus                 # suite: one operation, web actor
      mix sp.gen.feature position                           # suite: whole constituent

  After a run that wrote files (any run but `--dry-run`), the binding runs
  `mix format` inside `services/api`. That is the project's own formatter
  engine — the same one the Elixir tool applied inside `SpGen.Merge`, on
  the same token stream — so generated files land formatted without the
  binary ever owning a formatter.

  The generators are idempotent and append-only, so the tree keeps
  compiling after every run (references to not-yet-generated citizens
  stay deferred). The binary also works standalone from anywhere in the
  repo:

      tools/spgen-rs/target/release/spgen-elixir <generator> <element> [options]

  Port status: generators not transferred to Rust yet answer with a pointer
  to the Elixir tool (`tools/spgen`), which stays live until every wave of
  the parity gate is green.
  """

  use Mix.Task

  @impl Mix.Task
  def run(argv), do: exec(argv)

  @doc false
  @spec delegate(atom(), [String.t()]) :: :ok
  def delegate(generator, argv), do: exec([Atom.to_string(generator) | argv])

  defp exec(args) do
    # an explicit --root points the whole run — binary and format pass —
    # at one repository; the default is found from the host project
    root = passed_root(args) || repo_root()
    bin = executable("spgen-elixir")
    # a bare `mix sp.gen` is the listing and takes no root; any generator
    # run gets the root stated once, explicitly
    args =
      cond do
        args == [] -> []
        "--root" in args -> args
        true -> args ++ ["--root", root]
      end

    {_out, status} = System.cmd(bin, args, into: IO.stream(:stdio, :line))

    if status != 0, do: Mix.raise("spgen-elixir exited with status #{status}")

    # deferral guidance keeps exit 0; the bare listing writes nothing;
    # a leading option means the binary just listed; only a real generator
    # or suite run needs the project formatter pass
    cond do
      args == [] -> :ok
      "--dry-run" in args -> :ok
      match?([<<"-", _::binary>>, _ | _], args) -> :ok
      true -> format_project(root)
    end

    :ok
  end

  defp passed_root(args) do
    case Enum.find_index(args, &(&1 == "--root")) do
      nil -> nil
      i -> Enum.at(args, i + 1)
    end
  end

  defp format_project(root) do
    api = Path.join(root, "services/api")

    case System.cmd("mix", ["format"], cd: api, stderr_to_stdout: true) do
      {_out, 0} -> :ok
      {out, status} -> Mix.raise("mix format failed (status #{status}):\n#{out}")
    end
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
      File.dir?(Path.join(dir, "tools/spgen-rs"))
  end

  # The binary lives in this workspace, not in the (possibly sandboxed)
  # repository a run targets: resolve it from the source location of this
  # module — a path dependency keeps its real path.
  @doc false
  @spec validate([String.t()]) :: :ok
  def validate(argv) do
    # the model-completeness gate, sp.check's successor: the spgen binary
    # owns the validate engine; findings stream out and the exit status is the
    # answer (1 = the model owes work, 0 = every listed element generates clean)
    root = passed_root(argv) || repo_root()
    bin = executable("spgen")
    args = if "--root" in argv, do: argv, else: argv ++ ["--root", root]

    {_out, status} = System.cmd(bin, ["validate" | args], into: IO.stream(:stdio, :line))
    if status != 0, do: System.halt(status)
    :ok
  end

  defp executable(package) do
    workspace = Path.expand("../../../..", __DIR__)
    bin = Path.join(workspace, "target/release/#{package}")

    unless File.exists?(bin) do
      if autobuild?() do
        build(workspace, package)
      else
        Mix.raise("#{package} missing at #{bin} — run `cargo build --release -p #{package}`")
      end
    end

    if autobuild?() && File.exists?(bin) && stale?(workspace, bin), do: build(workspace, package)
    bin
  end

  defp autobuild?, do: System.get_env("SPGEN_NO_AUTOBUILD") in [nil, ""]

  # the FE wrapper's rule, ported: sources newer than the binary rebuild it
  defp stale?(workspace, bin) do
    bin_mtime = File.stat!(bin).mtime

    sources(workspace)
    |> Enum.any?(fn path ->
      case File.stat(path) do
        {:ok, %{mtime: m}} -> m > bin_mtime
        _ -> false
      end
    end)
  end

  defp sources(workspace) do
    Path.wildcard(Path.join(workspace, "crates/**/*.rs")) ++
      Path.wildcard(Path.join(workspace, "crates/**/Cargo.toml")) ++
      [
        Path.join(workspace, "Cargo.toml"),
        Path.join(workspace, "Cargo.lock")
      ]
  end

  defp build(workspace, package) do
    Mix.shell().info("(building #{package}…)")

    case System.cmd("cargo", ["build", "--release", "--quiet", "-p", package],
           cd: workspace,
           stderr_to_stdout: true
         ) do
      {_out, 0} -> :ok
      {out, status} -> Mix.raise("building #{package} failed (status #{status}):\n#{out}")
    end
  end
end
