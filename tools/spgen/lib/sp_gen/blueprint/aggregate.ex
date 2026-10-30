defmodule SpGen.Blueprint.Aggregate do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/aggregate.md`
  — the aggregate module file itself.

  Generates the aggregate module (or appends to an existing one): state
  fields and one `apply/2` clause per event of the aggregate — body chosen by
  what the event's projection does to the read model (`create` sets state,
  `update` merges changes, `delete` terminates the aggregate with `nil`).

  Fixed shape: the events drive everything, no `--template`.
  """

  use SpGen.Blueprint

  alias SpGen.Esdm
  alias SpGen.Blueprint.Event

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/aggregate.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate"
  @event_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>"

  def name, do: :aggregate
  def source_kinds, do: [:aggregate, :command, :event]

  @doc "The aggregate's module-name template (referenced by `AggregateTest`)."
  def module_template, do: @module

  @doc "The aggregate module's file path (used as a `requires` gate)."
  @spec module_file(Context.t()) :: String.t()
  def module_file(%Context{} = ctx), do: Context.render(@path, ctx)

  def plans(%Context{} = ctx) do
    [
      %FilePlan{
        path: Context.render(@path, ctx),
        module: Context.render(@module, ctx),
        units: units(ctx),
        unit_created: true
      }
    ]
  end

  defp moduledoc_text(ctx) do
    case Esdm.describe(ctx.element) do
      nil ->
        "TODO: Aggregate representing a #{ctx.constituent} in the #{Context.bounded_context(ctx)}."

      desc ->
        desc
    end
  end

  defp projection_for(ctx, event) do
    if ctx.read_model do
      Enum.find(Esdm.projections(ctx.read_model), fn p -> p["event"] == event.name end)
    end
  end

  # ------------------------------------------------------------------- units

  defp units(ctx) do
    events = Esdm.events_of(ctx.model, ctx.constituent)

    [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          """
          @moduledoc \"\"\"
          #{moduledoc_text(c)}
          \"\"\"
          """
        end,
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:use, "TypedStruct"},
        check: fn src -> Source.has_use?(src, "TypedStruct") end,
        render: fn _ctx -> "use TypedStruct" end,
        place: Merge.head(:use)
      }
    ] ++
      Enum.map(events, fn e ->
        full = Context.render(@event_module, %{ctx | element: e})

        %Unit{
          id: {:alias, full},
          check: fn src -> Source.has_alias?(src, full) end,
          render: fn _ctx -> "alias #{full}" end,
          requires: event_gate(ctx, e),
          place: Merge.alias_of(full)
        }
      end) ++
      field_units(ctx) ++
      Enum.map(events, fn e ->
        %Unit{
          id: {:apply, e.name},
          check: fn src -> Source.def_head_has?(src, :apply, 2, event_key(ctx, e)) end,
          render: fn c ->
            apply_clause(c, e, Esdm.projection_effect(projection_for(c, e)))
          end,
          requires: event_gate(ctx, e),
          place: Merge.after_def(:apply, 2)
        }
      end)
  end

  # the event's own module file must exist before the aggregate may
  # reference it (alias + pattern match on its struct)
  defp event_gate(ctx, %Element{} = e) do
    path = Event.module_file(%{ctx | element: e})
    reason = "event #{e.name} not generated (spgen event #{e.name})"
    fn _ctx -> [{path, reason}] end
  end

  defp event_key(ctx, e), do: Context.render("<Event>", %{ctx | element: e}) <> "{}"

  defp field_units(ctx) do
    Enum.map(ctx.fields, fn f ->
      key = ":#{f.name}"

      %Unit{
        id: {:field, f.name},
        check: fn src -> Source.entry?(src, :field, key) end,
        render: fn _ctx -> "field :#{f.name}, #{Context.elixir_type(f)}" end,
        place: Merge.inside(:typedstruct, fn _ctx, text -> "typedstruct do\n#{text}\nend" end)
      }
    end)
  end

  # --------------------------------------------------------------- clauses

  @doc false
  def apply_clause(ctx, event, effect) do
    aggregate = Context.render("<DomainObject>Aggregate", ctx)

    event_pascal =
      event.name |> String.split("-") |> Enum.map(&String.capitalize/1) |> Enum.join()

    case effect do
      :update ->
        """
        def apply(%#{aggregate}{} = aggregate, %#{event_pascal}{} = event) do
          changes = #{event_pascal}.get_changes(event)

          aggregate
          |> Map.merge(changes)
        end
        """

      :delete ->
        """
        def apply(%#{aggregate}{} = _aggregate, %#{event_pascal}{} = _event) do
          nil
        end
        """

      _create ->
        body =
          ctx.fields
          |> Enum.map(fn f -> "      #{f.name}: event.#{f.name}," end)
          |> Enum.join("\n")
          |> String.replace_trailing(",", "")

        """
        def apply(%#{aggregate}{} = _aggregate, %#{event_pascal}{} = event) do
          %#{aggregate}{
        #{body}
          }
        end
        """
    end
  end
end
