defmodule SpGen.Blueprint.CommandApplication do
  @moduledoc """
  Registers the composite's commanded router with its subdomain application
  (`use Commanded.Application`): without the `router` line the dispatch
  middleware of a freshly created composite answers `:unregistered_command`,
  which no generated file complains about.

  The subdomain's `application.ex` is a registration file, and like the
  router it is created when missing, so `mix sp.gen.command` works for the
  first composite of a subdomain. Starting that application from the root
  supervisor stays the operator's per-subdomain step (it also owns the Repo
  and the test case template).
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.CommandRouter

  @app_path "services/api/lib/sportipedia/<_subdomain>/application.ex"
  @app_module "Sportipedia.<Subdomain>"
  @router_module "Sportipedia.<Subdomain>.<Composite>.Router"
  @otp_app "sportipedia"

  @doc "The subdomain application's path (the gate for supervised children)."
  @spec module_file(Context.t()) :: String.t()
  def module_file(%Context{} = ctx), do: Context.render(@app_path, ctx)

  def plans(%Context{} = ctx) do
    router = Context.render(@router_module, ctx)

    [
      %FilePlan{
        path: Context.render(@app_path, ctx),
        module: Context.render(@app_module, ctx),
        unit_created: true,
        units: [
          %Unit{
            id: {:use, "Commanded.Application"},
            check: fn src -> Source.has_use?(src, "Commanded.Application") end,
            render: fn _ctx -> "use Commanded.Application, otp_app: :#{@otp_app}" end,
            place: Merge.head(:use)
          },
          %Unit{
            id: {:app_router, router},
            check: fn src -> Source.entry?(src, :router, router) end,
            requires: fn c ->
              [{CommandRouter.module_file(c), "router not generated (spgen command)"}]
            end,
            render: fn _ctx -> "router #{router}" end,
            place:
              Merge.after_macro(
                :router,
                fn _ -> true end,
                Merge.body_end()
              )
          }
        ]
      }
    ]
  end
end
