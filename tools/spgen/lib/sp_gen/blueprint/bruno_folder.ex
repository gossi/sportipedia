defmodule SpGen.Blueprint.BrunoFolder do
  @moduledoc """
  The constituent's `folder.yml` in the Bruno collection — created alongside
  the first request it contains (`info.seq` orders it among its sibling
  folders, `request.auth: inherit` defers to the parent folders' auth).
  """

  use SpGen.Blueprint

  @dir "bruno/<Subdomain>/<Composite>/<Constituent>"

  def plans(%Context{} = ctx) do
    [folder_plan(ctx)]
  end

  defp folder_plan(ctx) do
    path = Context.render("#{@dir}/folder.yml", ctx)

    %FilePlan{
      path: path,
      module: nil,
      scaffold: fn c -> folder_scaffold(c, path) end,
      units: [],
      format: false
    }
  end

  defp folder_scaffold(ctx, path) do
    """
    info:
      name: #{Context.pascal(ctx.constituent)}
      type: folder
      seq: #{folder_seq(ctx, path)}

    request:
      auth: inherit
    """
  end

  # seq = number of constituent folders present (this one included)
  defp folder_seq(ctx, path) do
    composite = ctx.repo_root && Path.join(ctx.repo_root, Path.dirname(Path.dirname(path)))

    with true <- composite && FS.dir?(ctx.fs, composite),
         {:ok, entries} <- FS.ls(ctx.fs, composite) do
      entries
      |> Enum.count(fn e -> FS.dir?(ctx.fs, Path.join(composite, e)) end)
      |> max(1)
    else
      _ -> 1
    end
  end
end
