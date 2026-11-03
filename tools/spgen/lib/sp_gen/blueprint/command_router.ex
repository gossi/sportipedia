defmodule SpGen.Blueprint.CommandRouter do
  @moduledoc """
  Registers the command in the composite's commanded router
  (`docs/architecture/blueprints/backend/domain/command.md` — Registration):
  aliases for command, handler and aggregate, the `identify` entry (once per
  aggregate) and the `dispatch` entry grouping the command with its handler.

  The router is a registration file, but a composite is not allowed to lack
  one: when it is missing the generator creates it with its own skeleton
  (`use Commanded.Commands.Router` and the two middlewares), so
  `mix sp.gen.command` never fails on the composite's first command.
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.{Aggregate, Command, CommandHandler}

  @router_path "services/api/lib/sportipedia/<_subdomain>/<composite>/router.ex"
  @router_module "Sportipedia.<Subdomain>.<Composite>.Router"
  @aggregate_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate"
  @middlewares ["Identity", "Validate"]

  @doc "The composite router's path — the gate for app and router registrations."
  @spec module_file(Context.t()) :: String.t()
  def module_file(%Context{} = ctx), do: Context.render(@router_path, ctx)

  def plans(%Context{} = ctx) do
    command = Context.render("<Command>", ctx)
    handler = command <> "Handler"
    aggregate = Context.render("<DomainObject>Aggregate", ctx)

    cmd_gate = fn c -> [{Command.module_file(c), "command not generated (spgen command)"}] end

    handler_gate = fn c ->
      [{CommandHandler.module_file(c), "handler not generated (spgen command_handler)"}]
    end

    agg_gate = fn c ->
      [{Aggregate.module_file(c), "aggregate not generated (spgen aggregate)"}]
    end

    [
      %FilePlan{
        path: module_file(ctx),
        module: Context.render(@router_module, ctx),
        unit_created: true,
        units:
          [use_unit()] ++
            Enum.flat_map(@middlewares, &middleware_units/1) ++
            [
              registration_alias(Context.render(Command.module_template(), ctx), cmd_gate),
              registration_alias(
                Context.render(Command.module_template(), ctx) <> "Handler",
                handler_gate
              ),
              registration_alias(Context.render(@aggregate_module, ctx), agg_gate),
              identify_unit(ctx, aggregate, agg_gate),
              dispatch_unit(command, handler, aggregate, [cmd_gate, handler_gate, agg_gate])
            ]
      }
    ]
  end

  defp use_unit do
    %Unit{
      id: {:use, "Commanded.Commands.Router"},
      check: fn src -> Source.has_use?(src, "Commanded.Commands.Router") end,
      render: fn _ctx -> "use Commanded.Commands.Router" end,
      place: Merge.head(:use)
    }
  end

  # the support middlewares exist repo-wide, so these need no gate
  defp middleware_units(name) do
    full = "Sportipedia.Support.Commanded.Middleware." <> name

    [
      %Unit{
        id: {:router_alias, full},
        check: fn src -> Source.has_alias?(src, full) end,
        render: fn _ctx -> "alias #{full}" end,
        place: Merge.alias_of(full)
      },
      %Unit{
        id: {:middleware, name},
        check: fn src -> Source.entry?(src, :middleware, name) end,
        render: fn _ctx -> "middleware #{name}" end,
        place:
          Merge.after_macro(
            :middleware,
            fn _ -> true end,
            Merge.body_end()
          )
      }
    ]
  end

  defp registration_alias(full, gate) do
    %Unit{
      id: {:router_alias, full},
      check: fn src -> Source.has_alias?(src, full) end,
      render: fn _ctx -> "alias #{full}" end,
      requires: gate,
      place: Merge.alias_of(full)
    }
  end

  defp identify_unit(_ctx, aggregate, gate) do
    %Unit{
      id: {:identify, aggregate},
      check: fn src -> Source.entry?(src, :identify, aggregate) end,
      requires: gate,
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

  defp dispatch_unit(command, handler, aggregate, gates) do
    %Unit{
      id: {:dispatch, command},
      check: fn src -> Source.entry?(src, :dispatch, command) end,
      requires: fn c -> Enum.flat_map(gates, & &1.(c)) end,
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
