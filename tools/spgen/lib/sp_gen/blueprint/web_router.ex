defmodule SpGen.Blueprint.WebRouter do
  @moduledoc """
  Registers the endpoint route in the web router's scope chain
  (`/«subdomain» → /«composite» → /«domain-object»s`), materializing missing
  scope levels as nested blocks. Identified per `(verb, action)` — paths like
  `"/"` collide across scopes.
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.Controller

  @router_path "services/api/lib/sportipedia_web/router.ex"

  def plans(%Context{} = ctx) do
    op = Context.op_snake(ctx)
    verb = if ctx.element.kind == :command, do: :post, else: :get
    chain = scope_spec(ctx)
    paths = Enum.map(chain, &elem(&1, 0))
    controller = Context.pascal(ctx.constituent) <> "Controller"
    line = "#{verb} \"#{Controller.route_path(ctx)}\", #{controller}, :#{op}"

    [
      %FilePlan{
        path: @router_path,
        module: "SportipediaWeb.Router",
        scaffold: nil,
        units: [
          %Unit{
            id: {:route, ":#{op}"},
            check: fn src -> Source.route_present?(src, verb, ":#{op}", paths) end,
            render: fn _ctx -> line end,
            place: Merge.scope(chain)
          }
        ]
      }
    ]
  end

  @doc false
  def scope_spec(ctx) do
    [
      {"/" <> ctx.subdomain, "SportipediaWeb." <> Context.pascal(ctx.subdomain)},
      {"/" <> ctx.composite, Context.pascal(ctx.composite)},
      {"/" <> ctx.constituent <> "s", Context.pascal(ctx.constituent)}
    ]
  end
end
