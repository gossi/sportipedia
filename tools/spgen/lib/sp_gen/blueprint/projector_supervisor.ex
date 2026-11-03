defmodule SpGen.Blueprint.ProjectorSupervisor do
  @moduledoc """
  Registers the projector at the nearest supervisor
  (`docs/architecture/blueprints/backend/domain/projector.md` — Registration):
  appends the projector module to the `children` list of the composite's
  supervisor, falling back to the subdomain's supervisor.

  A subdomain without any supervisor gets one created here (with its
  `start_link/1` and `init/1` skeleton), so the projector never registers
  into a file that does not exist; starting that supervisor from the root
  application stays the operator's per-subdomain step.
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.Projector

  # nearest first: composite, then subdomain — the last is the created one
  @candidates [
    {"services/api/lib/sportipedia/<_subdomain>/<composite>/supervisor.ex",
     "Sportipedia.<Subdomain>.<Composite>.Supervisor"},
    {"services/api/lib/sportipedia/<_subdomain>/supervisor.ex",
     "Sportipedia.<Subdomain>.Supervisor"}
  ]

  def plans(%Context{} = ctx) do
    module = Context.render(SpGen.Blueprint.Projector.module_template(), ctx)
    {path, supervisor} = target(ctx)

    [
      %FilePlan{
        path: path,
        module: supervisor,
        unit_created: true,
        units: skeleton_units() ++ [child_unit(module)]
      }
    ]
  end

  # the nearest existing supervisor, else the subdomain's (to be created)
  defp target(ctx) do
    Enum.find_value(@candidates, fn {path_tpl, module_tpl} ->
      path = Context.render(path_tpl, ctx)

      if ctx.repo_root && File.exists?(Path.join(ctx.repo_root, path)) do
        {path, Context.render(module_tpl, ctx)}
      end
    end)

    {path_tpl, module_tpl} = List.last(@candidates)
    {Context.render(path_tpl, ctx), Context.render(module_tpl, ctx)}
  end

  defp skeleton_units do
    [
      %Unit{
        id: {:use, "Supervisor"},
        check: fn src -> Source.has_use?(src, "Supervisor") end,
        render: fn _ctx -> "use Supervisor" end,
        place: Merge.head(:use)
      },
      %Unit{
        id: {:def, :start_link, 1},
        check: fn src -> Source.has_def?(src, :start_link, 1) end,
        render: fn _ctx ->
          """
          def start_link(arg) do
            Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
          end
          """
        end,
        place: Merge.body_end()
      },
      %Unit{
        id: {:def, :init, 1},
        check: fn src -> Source.has_def?(src, :init, 1) end,
        render: fn _ctx ->
          """
          def init(_arg) do
            children = []

            Supervisor.init(children, strategy: :one_for_one)
          end
          """
        end,
        place: Merge.body_end()
      }
    ]
  end

  defp child_unit(module) do
    %Unit{
      id: {:child, module},
      check: fn src -> Source.has_child?(src, module) end,
      render: fn _ctx -> module end,
      requires: fn c ->
        [{Projector.module_file(c), "projector not generated (spgen projector)"}]
      end,
      place: Merge.children_list()
    }
  end
end
