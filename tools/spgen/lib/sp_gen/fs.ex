defmodule SpGen.FS do
  @moduledoc """
  The generator's only view of the filesystem.

  `SpGen` reads and writes files exclusively through this behaviour, which
  makes the whole tool runnable against a repository that does not exist on
  disk: the tests drive it over an in-memory filesystem (`SpGen.FS.VFS`,
  test-only), production uses `SpGen.FS.Local`, and the escript behaves exactly
  as it did before.

  A handle is `{backend_module, backend_state}` — `{SpGen.FS.Local, nil}` for
  the disk, `{SpGen.FS.VFS, pid}` for memory. Paths are plain strings, produced
  by `Path` from the run's repo root; how they resolve is the backend's
  business.

  The surface is deliberately the handful of things generation does: read,
  write (creating parents), existence, directory tests, listing, and the
  recursive walk the model loader needs.
  """

  alias SpGen.FS.Local

  @typedoc "The backend's own state: `nil` for the disk, a process for memory."
  @type state :: term()

  @typedoc "`{backend, state}` — pass it to every function in this module."
  @type t :: {module(), state()}

  @callback read(state(), Path.t()) :: {:ok, binary()} | {:error, term()}
  @callback write(state(), Path.t(), iodata()) :: :ok | {:error, term()}
  @callback mkdir_p(state(), Path.t()) :: :ok | {:error, term()}
  @callback exists?(state(), Path.t()) :: boolean()
  @callback dir?(state(), Path.t()) :: boolean()
  @callback ls(state(), Path.t()) :: {:ok, [String.t()]} | {:error, term()}
  @callback files(state(), Path.t()) :: [String.t()]

  @doc "The handle production runs against: the real disk."
  @spec default() :: t()
  def default, do: {Local, nil}

  @spec read(t(), Path.t()) :: {:ok, binary()} | {:error, term()}
  def read({mod, state}, path), do: mod.read(state, path)

  @doc "Read a file, raising with the backend's reason when it is missing."
  @spec read!(t(), Path.t()) :: binary()
  def read!({mod, _state} = handle, path) do
    case read(handle, path) do
      {:ok, text} -> text
      {:error, reason} -> raise "#{inspect(mod)}: cannot read #{path}: #{inspect(reason)}"
    end
  end

  @doc "Write a file, creating its parent directories."
  @spec write(t(), Path.t(), iodata()) :: :ok | {:error, term()}
  def write({mod, state} = handle, path, content) do
    with :ok <- mkdir_p(handle, Path.dirname(path)) do
      mod.write(state, path, content)
    end
  end

  @doc "Write a file, raising on failure."
  @spec write!(t(), Path.t(), iodata()) :: :ok
  def write!(handle, path, content) do
    case write(handle, path, content) do
      :ok ->
        :ok

      {:error, reason} ->
        raise "#{inspect(elem(handle, 0))}: cannot write #{path}: #{inspect(reason)}"
    end
  end

  @spec mkdir_p(t(), Path.t()) :: :ok | {:error, term()}
  def mkdir_p({mod, state}, path), do: mod.mkdir_p(state, path)

  @spec exists?(t(), Path.t()) :: boolean()
  def exists?({mod, state}, path), do: mod.exists?(state, path)

  @spec dir?(t(), Path.t()) :: boolean()
  def dir?({mod, state}, path), do: mod.dir?(state, path)

  @doc "Names directly inside a directory."
  @spec ls(t(), Path.t()) :: {:ok, [String.t()]} | {:error, term()}
  def ls({mod, state}, path), do: mod.ls(state, path)

  @doc "Every regular file under `root`, sorted — the model loader's walk."
  @spec files(t(), Path.t()) :: [String.t()]
  def files({mod, state}, root), do: mod.files(state, root)

  @doc "Regular files under `root` whose path ends with `suffix`, sorted."
  @spec files_with(t(), Path.t(), String.t()) :: [Path.t()]
  def files_with(handle, root, suffix) do
    handle |> files(root) |> Enum.filter(&String.ends_with?(&1, suffix))
  end

  @doc "True when `path` is a file or directory in `handle`."
  @spec missing?(t(), Path.t()) :: boolean()
  def missing?(handle, path), do: not exists?(handle, path)
end
