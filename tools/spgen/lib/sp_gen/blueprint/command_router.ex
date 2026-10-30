defmodule SpGen.Blueprint.CommandRouter do
  @moduledoc """
  Registers the command in the composite's commanded router
  (`docs/architecture/blueprints/backend/domain/command.md` — Registration):
  aliases for command, handler and aggregate, the `identify` entry (once per
  aggregate) and the `dispatch` entry grouping the command with its handler.
  """

  use SpGen.Blueprint

  alias SpGen.Blueprint.{Aggregate, Command, CommandHandler}

  @router_path "services/api/lib/sportipedia/<_subdomain>/<composite>/router.ex"
  @aggregate_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate"

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
        path: Context.render(@router_path, ctx),
        module: nil,
        scaffold: nil,
        units:
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
          |> Enum.reject(&is_nil/1)
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
