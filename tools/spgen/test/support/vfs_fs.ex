defmodule SpGen.FS.VFS do
  @moduledoc """
  Test-only `SpGen.FS` backend over the `vfs` package's in-memory tree.

  `VFS` threads its state through every call (`{:ok, value, fs}`), which is
  right for a value-oriented filesystem and wrong for a generator that just
  wants to read and write. The `Agent` here owns the `%VFS.Memory{}` and threads
  it internally, so spgen sees the same handle shape as the disk backend.

  Errors normalize to the POSIX atoms `File.read/1` returns (`:enoent`, …), so
  the generator's `{:error, :enoent}` branches behave identically in memory.
  """

  @behaviour SpGen.FS

  alias VFS.Error
  alias VFS.Stat

  @doc "Start an in-memory repository seeded with `%{absolute_path => content}`."
  def start_link(files \\ %{}) do
    Agent.start_link(fn -> VFS.Memory.new(files) end)
  end

  @doc "The `{backend, state}` handle `SpGen.FS` dispatches on."
  @spec handle(pid()) :: SpGen.FS.t()
  def handle(pid), do: {__MODULE__, pid}

  @doc "Every regular file in the repository, sorted (test assertions)."
  @spec paths(pid()) :: [String.t()]
  def paths(pid), do: files(pid, "/")

  @doc "Snapshot of the whole tree as `%{path => content}` (golden comparisons)."
  @spec snapshot(pid()) :: %{String.t() => binary()}
  def snapshot(pid) do
    pid
    |> paths()
    |> Map.new(fn path -> {path, read!(pid, path)} end)
  end

  defp read!(pid, path) do
    case read(pid, path) do
      {:ok, text} -> text
      {:error, reason} -> raise "VFS: cannot read #{path}: #{inspect(reason)}"
    end
  end

  defp thread(pid, fun) do
    Agent.get_and_update(pid, fun)
  end

  defp kind(%Error{kind: kind}), do: kind
  defp kind(other), do: other

  @impl true
  def read(pid, path) do
    thread(pid, fn fs ->
      case VFS.read_file(fs, path) do
        {:ok, text, fs} -> {{:ok, text}, fs}
        {:error, err} -> {{:error, kind(err)}, fs}
      end
    end)
  end

  @impl true
  def write(pid, path, content) do
    thread(pid, fn fs ->
      case VFS.write_file(fs, path, IO.iodata_to_binary(content)) do
        {:ok, fs} -> {:ok, fs}
        {:error, err} -> {{:error, kind(err)}, fs}
      end
    end)
  end

  @impl true
  def mkdir_p(pid, path) do
    thread(pid, fn fs ->
      case VFS.mkdir(fs, path, parents: true) do
        {:ok, fs} -> {:ok, fs}
        {:error, %Error{kind: :eexist}} -> {:ok, fs}
        {:error, err} -> {{:error, kind(err)}, fs}
      end
    end)
  end

  @impl true
  def exists?(pid, path) do
    thread(pid, fn fs ->
      {exists, fs} = VFS.exists?(fs, path)
      {exists, fs}
    end)
  end

  @impl true
  def dir?(pid, path) do
    thread(pid, fn fs ->
      case VFS.stat(fs, path) do
        {:ok, %Stat{type: :directory}, fs} -> {true, fs}
        {:ok, _stat, fs} -> {false, fs}
        {:error, _err} -> {false, fs}
      end
    end)
  end

  @impl true
  def ls(pid, path) do
    thread(pid, fn fs ->
      case VFS.readdir(fs, path) do
        {:ok, names, fs} -> {{:ok, Enum.to_list(names)}, fs}
        {:error, err} -> {{:error, kind(err)}, fs}
      end
    end)
  end

  @impl true
  def files(pid, root) do
    pid
    |> Agent.get(fn fs -> fs |> VFS.walk(root) |> Enum.map(&elem(&1, 0)) end)
    |> Enum.sort()
    |> Enum.uniq()
  end
end
