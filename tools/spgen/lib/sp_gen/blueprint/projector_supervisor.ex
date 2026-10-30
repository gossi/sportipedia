defmodule SpGen.Blueprint.ProjectorSupervisor do
  @moduledoc """
  Registers the projector at the nearest supervisor
  (`docs/architecture/blueprints/backend/domain/projector.md` — Registration):
  appends the projector module to the `children` list of the composite's
  supervisor, falling back to the subdomain's supervisor.
  """

  use SpGen.Blueprint

  @candidates [
    "services/api/lib/sportipedia/<_subdomain>/<composite>/supervisor.ex",
    "services/api/lib/sportipedia/<_subdomain>/supervisor.ex"
  ]

  def plans(%Context{} = ctx) do
    module = Context.render(SpGen.Blueprint.Projector.module_template(), ctx)

    [
      %FilePlan{
        path: supervisor_path(ctx),
        module: nil,
        scaffold: nil,
        units: [
          %Unit{
            id: {:child, module},
            check: fn src -> Source.has_child?(src, module) end,
            render: fn _ctx -> module end,
            place: Merge.children_list()
          }
        ]
      }
    ]
  end

  defp supervisor_path(ctx) do
    Enum.find_value(@candidates, fn tpl ->
      rendered = Context.render(tpl, ctx)

      if ctx.repo_root && File.exists?(Path.join(ctx.repo_root, rendered)), do: rendered
    end) || Context.render(List.last(@candidates), ctx)
  end
end
