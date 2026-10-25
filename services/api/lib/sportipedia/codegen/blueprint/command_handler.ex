defmodule Sportipedia.Codegen.Blueprint.CommandHandler do
  @moduledoc """
  Executable transfer of
  `docs/architecture/blueprints/backend/domain/command-handler.md` — the
  handler file itself.

  Generates the `commanded` command handler (one `handle/2` per command) with
  its `@behaviour`, aliases, `@doc`/`@spec`.

  The handler *shape* is identical for every operation (input command, output
  events) — only the event names differ, so this blueprint is **fixed**: no
  `--template`.

  The command registration in the commanded router (`dispatch … to: …
  Handler`) is contributed by the command router blueprint, not here.
  """

  use Sportipedia.Codegen.Blueprint

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>/handler.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>Handler"
  @aggregate_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate"
  @command_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>"
  @event_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>"

  def name, do: :command_handler
  def source_kinds, do: [:command]

  @doc false
  def module_template, do: @module
  @doc false
  def command_template, do: @command_module
  @doc false
  def aggregate_template, do: @aggregate_module
  @doc false
  def event_template, do: @event_module

  def plans(%Context{} = ctx) do
    [
      %FilePlan{
        path: Context.render(@path, ctx),
        module: Context.render(@module, ctx),
        scaffold: &scaffold/1,
        units: units(ctx)
      }
    ]
  end

  @doc false
  def scaffold(ctx) do
    aliases = alias_block(ctx)
    event = event_render(ctx)

    """
    defmodule #{Context.render(@module, ctx)} do
      @moduledoc \"\"\"
      Handles the #{Context.render("<Command>", ctx)} command.
      \"\"\"

      @behaviour Commanded.Commands.Handler
    #{aliases}
      @doc \"\"\"
      Handles the #{Context.render("<Command>", ctx)} command and returns #{event} event(s).
      \"\"\"
      @spec handle(#{Context.render("<DomainObject>Aggregate", ctx)}.t(), #{Context.render("<Command>", ctx)}.t()) :: #{event}.t() | [#{event}.t()]
      def handle(%#{Context.render("<DomainObject>Aggregate", ctx)}{} = aggregate, %#{Context.render("<Command>", ctx)}{} = cmd) do
        # implement logic here
        # return events
      end
    end
    """
  end

  @doc "Pascal-cased first event name of the command, e.g. `ApparatusCataloged`."
  def event_render(ctx) do
    case ctx.events do
      [%{name: name} | _] ->
        name |> String.split("-") |> Enum.map(&String.capitalize/1) |> Enum.join()

      _ ->
        "Event"
    end
  end

  defp alias_block(ctx) do
    modules = alias_modules(ctx)
    "\n" <> Enum.map_join(modules, "\n", fn m -> "  alias #{m}" end) <> "\n"
  end

  @doc false
  def alias_modules(ctx) do
    aggregate = Context.render(@aggregate_module, ctx)
    command = Context.render(@command_module, ctx)

    events =
      Enum.map(ctx.events, fn ev ->
        Context.render(@event_module, %{ctx | element: ev})
      end)

    [aggregate, command] ++ events
  end

  # ------------------------------------------------------------------- units

  defp units(ctx) do
    behaviour_unit() ++ alias_units(ctx) ++ handle_units(ctx)
  end

  defp behaviour_unit do
    [
      %Unit{
        id: {:moduledoc, :handler},
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          """
          @moduledoc \"\"\"
          Handles the #{Context.render("<Command>", c)} command.
          \"\"\"
          """
        end,
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:behaviour, "Commanded.Commands.Handler"},
        check: fn src -> Source.has_behaviour?(src, "Commanded.Commands.Handler") end,
        render: fn _ctx -> "@behaviour Commanded.Commands.Handler" end,
        place: Merge.head(:attribute)
      }
    ]
  end

  defp alias_units(ctx) do
    ctx
    |> alias_modules()
    |> Enum.map(fn full ->
      %Unit{
        id: {:router_alias, full},
        check: fn src -> Source.has_alias?(src, full) end,
        render: fn _ctx -> "alias #{full}" end,
        place: Merge.alias_of(full)
      }
    end)
  end

  defp handle_units(ctx) do
    event = event_render(ctx)
    aggregate = Context.render("<DomainObject>Aggregate", ctx)
    command = Context.render("<Command>", ctx)

    [
      %Unit{
        id: {:def, :handle, 2},
        check: fn src -> Source.has_def?(src, :handle, 2) end,
        render: fn _ctx ->
          """
          @doc \"\"\"
          Handles the #{command} command and returns #{event} event(s).
          \"\"\"
          @spec handle(#{aggregate}.t(), #{command}.t()) :: #{event}.t() | [#{event}.t()]
          def handle(%#{aggregate}{} = aggregate, %#{command}{} = cmd) do
            # implement logic here
            # return events
          end
          """
        end,
        place: Merge.body_end()
      }
    ]
  end
end
