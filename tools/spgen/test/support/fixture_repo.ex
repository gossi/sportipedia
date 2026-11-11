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

  @doc """
  Overwrite `rel` — how a test states what hand-edited generated code looks like.
  """
  @spec write(t(), String.t(), String.t()) :: :ok
  def write(%__MODULE__{pid: pid, root: root}, rel, content) do
    :ok = SpGen.FS.VFS.write(pid, Path.join(root, rel), content)
    :ok
  end

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

  @doc """
  The whole repository as `%{repo_relative_path => content}`: the tree as pure,
  immutable data.

  Paired with `restore/1` it lets an expensive state — a fully generated citizen —
  be built once for a session and handed to every test that only reads it,
  instead of generating it again per test.
  """
  @spec contents(t()) :: %{String.t() => String.t()}
  def contents(%__MODULE__{} = repo) do
    Map.new(paths(repo), fn rel -> {rel, read(repo, rel)} end)
  end

  @doc """
  A fresh repository holding exactly `contents` (as `contents/1` returns it).

  Each call starts its own backend, so tests sharing one `contents` map stay
  isolated: writes land in the caller's copy and nowhere else.
  """
  @spec restore(%{String.t() => String.t()}) :: t()
  def restore(contents) do
    seed = Map.new(contents, fn {rel, text} -> {@root <> "/" <> rel, text} end)
    {:ok, pid} = SpGen.FS.VFS.start_link(seed)
    %__MODULE__{root: @root, fs: SpGen.FS.VFS.handle(pid), pid: pid}
  end

  @doc """
  Builds `fun` once per test session and gives every caller the result.

  For state that is expensive to produce and immutable to read — a fully
  generated citizen, the fixture model. The memo lives in a process started by
  `test_helper.exs`, so the work is shared across test cases *and* stays lazy: a
  run that never asks for the tree never pays for it.

  **The build runs in the caller, never inside the memo.** Building is seconds of
  work; holding a `GenServer.call` open for it makes every other caller wait on
  the default 5s timeout, and CI (8 cores, a cold chain) failed the tests that
  merely asked for the tree. So: read the cache, build outside the lock, store
  with first-writer-wins. Concurrent callers can each build once — a duplicated
  chain costs CPU a waiting caller would have burned anyway, and it cannot time
  out, because every message the memo handles is a map lookup.
  """
  @spec shared(term(), (-> term())) :: term()
  def shared(key, fun) do
    case memo_fetch(key) do
      {:ok, built} ->
        built

      :error ->
        value = fun.()
        memo_store_first(key, value)
        value
    end
  end

  # the memo is an optimization: with no memo process (a lone `iex -S mix`, the
  # helper used outside the suite) the call still returns a correct value
  defp memo_fetch(key) do
    case memo_pid() do
      nil -> :error
      _ -> Agent.get(SpGen.TestMemo, &Map.fetch(&1, key))
    end
  rescue
    _ -> :error
  end

  defp memo_store_first(key, value) do
    unless is_nil(memo_pid()) do
      # `get_and_update`, not `run`: the memo only ever answers map operations,
      # and each one returns immediately — which is the whole point (see
      # `shared/2`).
      Agent.get_and_update(SpGen.TestMemo, fn state ->
        {:ok, if(Map.has_key?(state, key), do: state, else: Map.put(state, key, value))}
      end)
    end

    :ok
  rescue
    _ -> :ok
  end

  defp memo_pid, do: Process.whereis(SpGen.TestMemo)

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

  @doc """
  The fixture domain model as an `Esdm` struct, read straight from `fixtures/`.

  For the tests that reason over a *model* (resolution, invariants, contexts,
  templates) rather than over generated code: the fixture model is the only
  model a test may load. The live `docs/domain-model` moves with the domain and
  is owned by nobody in this tool, so a model edit there would otherwise read as
  an spgen failure — and a test that cannot say which citizen it asserts on
  cannot be re-run against a changed model.
  """
  @spec model() :: SpGen.Esdm.t()
  def model do
    {:ok, model} = SpGen.Esdm.load(model_path())
    model
  end

  @doc "The fixture domain model's path — the only model root a test may load."
  @spec model_path() :: String.t()
  def model_path, do: Path.join(fixtures_dir(), "domain-model")

  @doc """
  One element of the fixture model, by its `kind.name` address. Raises when the
  fixture does not carry it: a test asking for a citizen the fixtures do not
  model must say so loudly rather than fall back to the live tree.
  """
  @spec element(String.t()) :: SpGen.Esdm.Element.t()
  def element(address), do: SpGen.Esdm.resolve!(model(), address)

  defp fixtures_dir do
    Path.expand("../../fixtures", __DIR__)
  end
end
