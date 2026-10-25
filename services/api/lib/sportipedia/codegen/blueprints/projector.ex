defmodule Sportipedia.Codegen.Blueprints.Projector do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/projector.md`.

  Generated from an ESDM **event**: adds its `project` clause to the
  constituent's projector (the file is created with this clause when missing)
  and registers the projector at the nearest supervisor. The clause body is
  chosen by what the event's projection does to the read model: `create`
  inserts, `update` merges changes, `delete` removes the row.
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.{Context, Esdm, FilePlan, Source, Templates, Unit}
  alias Sportipedia.Codegen.Blueprints.OperationTestFile

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/projector.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Projector"
  @read_model_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel"
  @internal_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal"
  @event_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>"
  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Command>Test"

  def name, do: :projector
  def source_kinds, do: [:event]
  def operations, do: [:create, :update, :delete]
  def optional_template?, do: true

  def plans(%Context{} = ctx) do
    [projector_file(ctx), supervisor(ctx)] ++ test_plans(ctx)
  end

  @doc "The projector's `:name` option, also used as metadata `handler_name`."
  def projection_name(%Context{} = ctx),
    do: Context.render("<_composite>.<domain_object>_projection", ctx)

  defp projector_file(ctx) do
    %FilePlan{
      path: Context.render(@path, ctx),
      role: :module,
      module: Context.render(@module, ctx),
      scaffold: &scaffold/1,
      units: units(ctx)
    }
  end

  defp scaffold(ctx) do
    event_pascal = Context.pascal(ctx.element.name)
    effect = Context.effect_for_event(ctx, ctx.element.name)

    """
    defmodule #{Context.render(@module, ctx)} do
      @moduledoc \"\"\"
      Projects #{ctx.constituent} events to the #{ctx.constituent} read model.
      \"\"\"

    #{use_block(ctx)}
      alias #{Context.render(@read_model_module, ctx)}
      alias #{Context.render(@internal_module, ctx)}
      alias #{Context.render(@event_module, ctx)}

    #{clause(ctx, effect, event_pascal) |> Templates.indent(2)}
    end
    """
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

    [
      %Unit{
        id: :moduledoc,
        check: &Source.has_moduledoc?/1,
        render: fn c ->
          "@moduledoc \"\"\"\nProjects #{c.constituent} events to the #{c.constituent} read model.\n\"\"\""
        end,
        anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
      },
      %Unit{
        id: {:use, "Commanded.Projections.Ecto"},
        check: fn src -> Source.has_use?(src, "Commanded.Projections.Ecto") end,
        render: fn c -> String.trim_trailing(use_block(c)) end,
        anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
      },
      alias_unit(Context.render(@read_model_module, ctx)),
      alias_unit(Context.render(@internal_module, ctx)),
      alias_unit(Context.render(@event_module, ctx)),
      %Unit{
        id: {:project, ctx.element.name},
        check: fn src -> Source.entry?(src, :project, event_pascal <> "{}") end,
        render: fn c ->
          clause(c, Context.effect_for_event(c, c.element.name), Context.pascal(c.element.name))
          |> Templates.indent(2)
        end,
        anchor: fn src, _ctx ->
          Source.after_entry(src, :project, fn _ -> true end, Source.module_end_anchor(src))
        end
      }
    ]
  end

  defp alias_unit(module) do
    %Unit{
      id: {:alias, module},
      check: fn src -> Source.has_alias?(src, module) end,
      render: fn _ctx -> "alias #{module}" end,
      anchor: fn src, _ctx -> Source.alias_anchor(src, module) end,
      gap: :tight
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

  # ---------------------------------------------------------- registration

  defp supervisor(ctx) do
    candidates = [
      "services/api/lib/sportipedia/<_subdomain>/<composite>/supervisor.ex",
      "services/api/lib/sportipedia/<_subdomain>/supervisor.ex"
    ]

    path =
      Enum.find_value(candidates, fn tpl ->
        rendered = Context.render(tpl, ctx)

        if ctx.repo_root && File.exists?(Path.join(ctx.repo_root, rendered)),
          do: rendered
      end) || Context.render(List.last(candidates), ctx)

    module = Context.render(@module, ctx)

    %FilePlan{
      path: path,
      role: :registration,
      module: nil,
      scaffold: nil,
      units: [
        %Unit{
          id: {:child, module},
          check: fn src -> Source.has_child?(src, module) end,
          # the existing first child keeps its own comma: we land above it
          render: fn _ctx -> "#{module}," end,
          anchor: fn src, _ctx ->
            case Source.children_anchor(src) do
              :no_children -> Source.module_end_anchor(src)
              anchor -> anchor
            end
          end,
          gap: :tight
        }
      ]
    }
  end

  # -------------------------------------------------------------------- test

  # the projector's tests live in the operation test file(s) of the commands
  # publishing this event
  defp test_plans(ctx) do
    publishers =
      ctx.model.elements
      |> Enum.filter(fn el -> el.kind == :command and ctx.element.name in Esdm.publishes(el) end)
      |> Enum.sort_by(& &1.name)

    plain = Context.render("<DomainObject>Projector", ctx)

    Enum.map(publishers, fn command ->
      OperationTestFile.plan(ctx,
        path: @test_path,
        module: @test_module,
        extra_vars: %{"operation" => command.name, "command" => command.name},
        alias_templates: [@module],
        describes: [{"<DomainObject>Projector - <Event>", &describe_body/2, [plain]}]
      )
    end)
  end

  @doc false
  def describe_body(ctx, subject) do
    projector = Context.render("<DomainObject>Projector", ctx)
    event_pascal = Context.pascal(ctx.element.name)
    read_model = Context.pascal(ctx.constituent) <> "ReadModel"
    sub = Context.pascal(ctx.subdomain)
    body = Templates.struct_body(ctx)

    """
    describe "#{subject}" do
      test "projects #{event_pascal} to the #{ctx.constituent} read model" do
        event = %#{event_pascal}{#{body}}

        metadata = %{
          handler_name: "#{projection_name(ctx)}",
          event_number: 1,
          event_id: UUID.uuid4(),
          stream_id: "#{ctx.constituent}-\#{event.id}",
          stream_version: 1,
          correlation_id: nil,
          causation_id: nil,
          created_at: DateTime.utc_now(),
          application: Sportipedia.#{sub},
          state: nil
        }

        assert :ok = #{projector}.handle(event, metadata)

        record = Repo.get!(#{read_model}, event.id)
        assert record.id == event.id
      end
    end
    """
  end
end
