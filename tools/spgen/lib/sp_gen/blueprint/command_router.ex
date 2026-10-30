defmodule SpGen.Blueprint.CommandRouter do
  @moduledoc """
  Registers the command in the composite's commanded router
  (`docs/architecture/blueprints/backend/domain/command.md` — Registration):
  aliases for command, handler and aggregate, the `identify` entry (once per
  aggregate) and the `dispatch` entry grouping the command with its handler.
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.Command

  @router_path "services/api/lib/sportipedia/<_subdomain>/<composite>/router.ex"
  @aggregate_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate"

  def plans(%Context{} = ctx) do
    command = Context.render("<Command>", ctx)
    handler = command <> "Handler"
    aggregate = Context.render("<DomainObject>Aggregate", ctx)

    [
      %FilePlan{
        path: Context.render(@router_path, ctx),
        module: nil,
        scaffold: nil,
        units:
          [
            registration_alias(Context.render(Command.module_template(), ctx)),
            registration_alias(Context.render(Command.module_template(), ctx) <> "Handler"),
            registration_alias(Context.render(@aggregate_module, ctx)),
            identify_unit(ctx, aggregate),
            dispatch_unit(command, handler, aggregate)
          ]
          |> Enum.reject(&is_nil/1)
      }
    ]
  end

  defp registration_alias(full) do
    %Unit{
      id: {:router_alias, full},
      check: fn src -> Source.has_alias?(src, full) end,
      render: fn _ctx -> "alias #{full}" end,
      place: Merge.alias_of(full)
    }
  end

  defp identify_unit(_ctx, aggregate) do
    %Unit{
      id: {:identify, aggregate},
      check: fn src -> Source.entry?(src, :identify, aggregate) end,
      render: fn c ->
        prefix = Context.render("<-composite>/<domain-object>/", c)
        "identify #{aggregate}, by: :id, prefix: \"#{prefix}\""
      end,
      place:
        Merge.after_macro(
          :dispatch,
          fn _ -> true end,
          Merge.after_macro(:middleware, fn _ -> true end, Merge.head(:attribute))
        )
    }
  end

  defp dispatch_unit(command, handler, aggregate) do
    %Unit{
      id: {:dispatch, command},
      check: fn src -> Source.entry?(src, :dispatch, command) end,
      render: fn _ctx ->
        "dispatch #{command}, to: #{handler}, aggregate: #{aggregate}"
      end,
      place:
        Merge.after_macro_kw(
          :dispatch,
          :aggregate,
          fn value -> value == aggregate end,
          Merge.after_macro(:identify, fn value -> value == aggregate end)
        )
    }
  end
end
