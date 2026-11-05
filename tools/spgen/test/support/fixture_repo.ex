defmodule SpGen.FixtureRepo do
  @moduledoc """
  A whole repository in memory for the tests: the fixture domain model and the
  hand-owned host files from `fixtures/`, mounted on a `SpGen.FS.VFS`
  handle under a virtual repo root.

  Nothing touches disk — `SpGen` reads the model and writes generated code
  through the same `SpGen.FS` handle production uses for the real tree, so the
  tests exercise the real code paths against a repository that is pure data.

      repo = FixtureRepo.build()
      {:ok, results} = SpGen.run(:command, ["create-widget", "--root", repo.root], fs: repo.fs)
      assert FixtureRepo.read(repo, "services/api/lib/.../command.ex") =~ "defmodule"
  """

  @root "/repo"

  @typedoc "The virtual repository: its root, its filesystem handle and backend pid."
  @type t :: %__MODULE__{root: String.t(), fs: SpGen.FS.t(), pid: pid()}

  defstruct [:root, :fs, :pid]

  @doc """
  Builds a repository from `fixtures/` (`domain-model/` and `repo/`).

  Options: `:only` — a list of fixture-relative path prefixes to include, e.g.
  `only: ["domain-model"]` for a repository without the registration hosts.
  """
  @spec build(keyword()) :: t()
  def build(opts \\ []) do
    only = Keyword.get(opts, :only, [])

    # reading the fixtures is the harness' one job on disk: from here on,
    # everything the generator does happens in memory
    seed =
      fixture_paths()
      |> Enum.filter(fn rel -> only == [] or Enum.any?(only, &String.starts_with?(rel, &1)) end)
      |> Map.new(fn rel ->
        {@root <> "/" <> mount(rel), File.read!(Path.join(fixtures_dir(), rel))}
      end)

    {:ok, pid} = SpGen.FS.VFS.start_link(seed)

    %__MODULE__{root: @root, fs: SpGen.FS.VFS.handle(pid), pid: pid}
  end

  # where a fixture lands in the repository: the model under `docs/`, the host
  # files at the repo root
  defp mount("domain-model/" <> rest), do: "docs/domain-model/" <> rest
  defp mount("repo/" <> rest), do: rest

  @doc """
  The fixture paths that make up a repository — the model and the host files,
  in `mount/1` form, sorted. Recorded data such as `snapshots/` is not part of
  a repository.
  """
  @spec fixture_paths() :: [String.t()]
  def fixture_paths do
    dir = fixtures_dir()

    dir
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(&Path.relative_to(&1, dir))
    |> Enum.filter(&mountable?/1)
    |> Enum.sort()
  end

  defp mountable?(rel),
    do: String.starts_with?(rel, "domain-model/") or String.starts_with?(rel, "repo/")

  @doc "Run arguments for `generator` against `repo` (`--root` included)."
  @spec argv(t(), [String.t()]) :: [String.t()]
  def argv(%__MODULE__{root: root}, args), do: args ++ ["--root", root]

  @doc "Run `generator` against the repository."
  @spec run(t(), atom(), [String.t()]) :: {:ok, [term()]} | {:error, String.t()}
  def run(%__MODULE__{} = repo, generator, args) do
    SpGen.run(generator, argv(repo, args), fs: repo.fs)
  end

  @doc "`--check` run: report drift without writing."
  @spec check(t(), atom(), [String.t()]) :: {:ok, [term()]} | {:error, String.t()}
  def check(%__MODULE__{} = repo, generator, args) do
    run(repo, generator, args ++ ["--check"])
  end

  @doc "Content of a repo-relative file."
  @spec read(t(), String.t()) :: String.t()
  def read(%__MODULE__{} = repo, rel) do
    case SpGen.FS.read(repo.fs, Path.join(repo.root, rel)) do
      {:ok, text} -> text
      {:error, reason} -> raise "fixture repo: #{rel} not written (#{inspect(reason)})"
    end
  end

  @doc "True when the repository holds `rel`."
  @spec exists?(t(), String.t()) :: boolean()
  def exists?(%__MODULE__{} = repo, rel), do: SpGen.FS.exists?(repo.fs, Path.join(repo.root, rel))

  @doc "Remove `rel` (a host file a run is expected to recreate)."
  @spec remove(t(), String.t()) :: :ok
  def remove(%__MODULE__{} = repo, rel) do
    Agent.update(repo.pid, fn fs ->
      case VFS.rm(fs, Path.join(repo.root, rel), recursive: true) do
        {:ok, fs} -> fs
        {:error, _} -> fs
      end
    end)

    :ok
  end

  @doc "Every generated or fixture file in the repository, repo-relative and sorted."
  @spec paths(t()) :: [String.t()]
  def paths(%__MODULE__{} = repo) do
    repo.fs
    |> SpGen.FS.files(repo.root)
    |> Enum.map(&Path.relative_to(&1, repo.root))
    |> Enum.sort()
  end

  @doc "The generated code tree as `%{repo_relative_path => content}`."
  @spec snapshot(t()) :: %{String.t() => binary()}
  def snapshot(%__MODULE__{} = repo) do
    repo
    |> paths()
    |> Map.new(fn rel -> {rel, read(repo, rel)} end)
  end

  @doc "Paths the generators wrote (everything outside the fixture set)."
  @spec generated_paths(t()) :: [String.t()]
  def generated_paths(%__MODULE__{} = repo) do
    fixtures = fixture_paths() |> Enum.map(&mount/1) |> MapSet.new()

    repo
    |> paths()
    |> Enum.reject(&MapSet.member?(fixtures, &1))
  end

  defp fixtures_dir do
    Path.expand("../../fixtures", __DIR__)
  end
end
