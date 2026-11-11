defmodule SpGen.Blueprint.Projector do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/projector.md`
  — the projector file itself.

  Generated from an ESDM **event**: adds its `project` clause to the
  constituent's projector (the file is created with this clause when missing).
  The clause body is chosen by the operation the read model *declares* for the
  event (`metadata.annotations."spgen.operation.<event>"`): `create` inserts, `update`
  merges changes, `delete` removes the row. A declared `none` means the event
  materializes nothing — no clause; an *undeclared* event is skipped and
  reported as a model gap (`mix sp.check` enforces the ledger).
  """

  use SpGen.Blueprint

  alias SpGen.Templates
  alias SpGen.Blueprint.{Event, InternalAPI, ReadModel}

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/projector.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Projector"
  @read_model_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"
  @internal_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal"
  @event_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>"

  def name, do: :projector
  def source_kinds, do: [:event]
  def operations, do: [:create, :update, :delete, :none]
  def optional_template?, do: true

  @doc false
  def module_template, do: @module

  @doc "The projector's file path (used as a `requires` gate)."
  @spec module_file(Context.t()) :: String.t()
  def module_file(%Context{} = ctx), do: Context.render(@path, ctx)

  @doc "The projector's `:name` option, also used as metadata `handler_name`."
  def projection_name(%Context{} = ctx),
    do: Context.render("<_composite>.<domain_object>_projection", ctx)

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

  defp use_block(ctx) do
    sub = Context.pascal(ctx.subdomain)

    """
      use Commanded.Projections.Ecto,
        application: Sportipedia.#{sub},
        repo: Sportipedia.#{sub}.Repo,
        name: "#{projection_name(ctx)}",
        schema_prefix: "#{ctx.subdomain}",
        consistency: :strong
    """
  end

  # ------------------------------------------------------------------- units

  defp units(ctx) do
    event_pascal = Context.pascal(ctx.element.name)
    effect = Context.effect_for_event(ctx, ctx.element.name)

    base = [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          "@moduledoc \"\"\"\nProjects #{c.constituent} events to the #{c.constituent} read model.\n\"\"\""
        end,
        place: Merge.head(:moduledoc)
      },
      %Unit{
        id: {:use, "Commanded.Projections.Ecto"},
        check: fn src -> Source.has_use?(src, "Commanded.Projections.Ecto") end,
        render: fn c -> String.trim_trailing(use_block(c)) end,
        place: Merge.head(:use)
      },
      alias_unit(Context.render(@read_model_module, ctx), fn c ->
        [{ReadModel.module_file(c), "read model not generated (spgen read_model)"}]
      end),
      alias_unit(Context.render(@internal_module, ctx), fn c ->
        [{InternalAPI.module_file(c), "internal API not generated (spgen internal_api)"}]
      end),
      alias_unit(Context.render(@event_module, ctx), fn c ->
        [{Event.module_file(c), "event not generated (spgen event)"}]
      end)
    ]

    # an effect the read model never declared (nil) or declared away (`none`)
    # generates no clause — the first is reported as an open model question,
    # the second is a decision, complete on its own
    case effect do
      nil -> base
      :none -> base
      effect -> base ++ [clause_unit(ctx, event_pascal, effect)]
    end
  end

  defp clause_unit(ctx, event_pascal, effect) do
    %Unit{
      id: {:project, ctx.element.name},
      check: fn src -> Source.entry?(src, :project, event_pascal <> "{}") end,
      render: fn _c -> clause(ctx, effect, event_pascal) end,
      requires: fn c ->
        [
          {ReadModel.module_file(c), "read model not generated (spgen read_model)"},
          {InternalAPI.module_file(c), "internal API not generated (spgen internal_api)"}
        ]
      end,
      place: Merge.after_macro(:project, fn _ -> true end)
    }
  end

  defp alias_unit(module, gate) do
    %Unit{
      id: {:alias, module},
      check: fn src -> Source.has_alias?(src, module) end,
      render: fn _ctx -> "alias #{module}" end,
      requires: gate,
      place: Merge.alias_of(module)
    }
  end

  # --------------------------------------------------------------- clauses

  @doc """
  The `project` clause for one event, body per the projection's effect on
  the read model.
  """
  @spec clause(Context.t(), Context.effect(), String.t()) :: String.t()
  def clause(ctx, effect, event_pascal) do
    read_model = Context.pascal(ctx.constituent) <> "ReadModel"
    internal = Context.pascal(ctx.constituent) <> "Internal"
    var = ctx.constituent
    label = ctx.element.name |> String.replace("-", "_")

    doc =
      case effect do
        :update ->
          "Projects an #{event_pascal} event to update the #{ctx.constituent} read model."

        :delete ->
          "Projects an #{event_pascal} event to hard-delete the #{ctx.constituent} read model."

        _create ->
          "Projects an #{event_pascal} event to the #{ctx.constituent} read model."
      end

    """
    @doc \"\"\"
    #{doc}
    \"\"\"
    project %#{event_pascal}{} = event, _metadata, fn multi ->
    #{body(effect, read_model, internal, var, label, event_pascal) |> String.trim_trailing() |> Templates.indent(2)}
    end
    """
  end

  defp body(:update, read_model, internal, var, label, event_pascal) do
    """
    case #{internal}.#{var}_by_id(event.id) do
      nil ->
        multi

      %#{read_model}{} = #{var} ->
        attrs = #{event_pascal}.get_changes(event)

        multi
        |> Ecto.Multi.update(
          :#{label},
          #{read_model}.update_changeset(#{var}, attrs)
        )
    end
    """
  end

  defp body(:delete, read_model, internal, var, label, _event_pascal) do
    """
    case #{internal}.#{var}_by_id(event.id) do
      nil ->
        multi

      %#{read_model}{} = #{var} ->
        multi
        |> Ecto.Multi.delete(:#{label}, #{var})
    end
    """
  end

  defp body(_create, read_model, _internal, _var, label, _event_pascal) do
    """
    multi
    |> Ecto.Multi.insert(
      :#{label},
      #{read_model}.insert_changeset(%#{read_model}{}, Map.from_struct(event))
    )
    """
  end
end
