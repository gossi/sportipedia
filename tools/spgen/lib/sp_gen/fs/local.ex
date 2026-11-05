defmodule SpGen.FS.Local do
  @moduledoc """
  The `File`-backed `SpGen.FS` backend — what the CLI and the mix tasks run.

  The state is `nil`: the filesystem itself is the state.
  """

  @behaviour SpGen.FS

  @impl true
  def read(_state, path), do: File.read(path)

  @impl true
  def write(_state, path, content), do: File.write(path, content)

  @impl true
  def mkdir_p(_state, path), do: File.mkdir_p(path)

  @impl true
  def exists?(_state, path), do: File.exists?(path)

  @impl true
  def dir?(_state, path), do: File.dir?(path)

  @impl true
  def ls(_state, path), do: File.ls(path)

  @impl true
  def files(_state, root) do
    root
    |> Path.join("**/*")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.sort()
  end
end
