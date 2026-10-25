defmodule Sportipedia.Codegen.Blueprints.Aggregate do
  @moduledoc """
  Executable transfer of `docs/architecture/blueprints/backend/domain/aggregate.md`.

  Generates the aggregate module (or merges into an existing one): state
  fields and one `apply/2` clause per event of the aggregate — body chosen by
  what the event's projection does to the read model (`create` sets state,
  `update` merges changes, `delete` terminates the aggregate with `nil`).

  Fixed shape: the events drive everything, no `--template`.
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.{Context, Esdm, FilePlan, Source, Templates, Unit}
  alias Sportipedia.Codegen.Blueprints.OperationTestFile

  @path "services/api/lib/sportipedia/<_subdomain>/<composite>/<domain_object>/aggregate.ex"
  @module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate"
  @event_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>"
  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Command>Test"

  def name, do: :aggregate
  def source_kinds, do: [:aggregate, :command, :event]

  def plans(%Context{} = ctx) do
    [aggregate_file(ctx)] ++ test_plans(ctx)
  end

  defp aggregate_file(ctx) do
    %FilePlan{
      path: Context.render(@path, ctx),
      role: :module,
      module: Context.render(@module, ctx),
      scaffold: &scaffold/1,
      units: units(ctx)
    }
  end

  @doc false
  def scaffold(ctx) do
    events = Esdm.events_of(ctx.model, ctx.constituent)

    aliases =
      Enum.map_join(events, "\n", fn e ->
        "  alias #{Context.render(@event_module, %{ctx | element: e})}"
      end)

    fields =
      ctx.fields
      |> Enum.map(fn f -> "    field :#{f.name}, #{Context.elixir_type(f)}" end)
      |> Enum.join("\n")

    applies =
      events
      |> Enum.map(fn e ->
        apply_clause(ctx, e, Esdm.projection_effect(projection_for(ctx, e)))
      end)
      |> Enum.join("\n\n")

    """
    defmodule #{Context.render(@module, ctx)} do
      @moduledoc \"\"\"
      #{moduledoc_text(ctx)}
      \"\"\"

      use TypedStruct

    #{aliases}

      typedstruct do
    #{fields}
      end

    #{applies}
    end
    """
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
        anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
      },
      %Unit{
        id: {:use, "TypedStruct"},
        check: fn src -> Source.has_use?(src, "TypedStruct") end,
        render: fn _ctx -> "use TypedStruct" end,
        anchor: fn src, _ctx -> {:after_line, Source.module_start_line(src)} end
      }
    ] ++
      Enum.map(events, fn e ->
        full = Context.render(@event_module, %{ctx | element: e})

        %Unit{
          id: {:alias, full},
          check: fn src -> Source.has_alias?(src, full) end,
          render: fn _ctx -> "alias #{full}" end,
          anchor: fn src, _ctx -> Source.alias_anchor(src, full) end,
          gap: :tight
        }
      end) ++
      field_units(ctx) ++
      Enum.map(events, fn e ->
        key = Context.render("<Event>", %{ctx | element: e}) <> "{}"

        %Unit{
          id: {:apply, e.name},
          check: fn src -> Source.def_head_has?(src, :apply, 2, key) end,
          render: fn c ->
            apply_clause(c, e, Esdm.projection_effect(projection_for(c, e)))
            |> Templates.indent(2)
          end,
          anchor: fn src, _ctx -> Source.def_anchor(src, :apply, 2) end
        }
      end)
  end

  defp field_units(ctx) do
    Enum.map(ctx.fields, fn f ->
      key = ":#{f.name}"

      %Unit{
        id: {:field, f.name},
        check: fn src -> Source.entry?(src, :field, key) end,
        render: fn _ctx -> "field :#{f.name}, #{Context.elixir_type(f)}" end,
        anchor: fn src, _ctx -> Source.inside_block(src, :typedstruct) end,
        gap: :tight
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

  # -------------------------------------------------------------------- test

  # the aggregate's tests live in every publishing command's operation test
  defp test_plans(ctx) do
    events = Esdm.events_of(ctx.model, ctx.constituent)

    events
    |> Enum.flat_map(fn e -> publishers(ctx, e.name) end)
    |> Enum.uniq()
    |> Enum.map(fn command_name ->
      OperationTestFile.plan(ctx,
        path: @test_path,
        module: @test_module,
        extra_vars: %{"operation" => command_name, "command" => command_name},
        alias_templates: [@module],
        describes: [{"<DomainObject>Aggregate", &describe_body/2}]
      )
    end)
  end

  defp publishers(ctx, event_name) do
    ctx.model.elements
    |> Enum.filter(fn el -> el.kind == :command and event_name in Esdm.publishes(el) end)
    |> Enum.map(& &1.name)
  end

  @doc false
  def describe_body(ctx, subject) do
    aggregate = Context.render("<DomainObject>Aggregate", ctx)
    events = Esdm.events_of(ctx.model, ctx.constituent)

    tests =
      Enum.map(events, fn e ->
        event_pascal =
          e.name |> String.split("-") |> Enum.map(&String.capitalize/1) |> Enum.join()

        """
        test "applies #{e.name} to aggregate state" do
          event = %#{event_pascal}{#{Templates.struct_body(%{ctx | element: e})}}

          result = #{aggregate}.apply(%#{aggregate}{}, event)

          assert result.id == event.id
        end
        """
      end)

    """
    describe "#{subject}" do
    #{tests |> Enum.join("\n\n") |> Templates.indent(2)}
    end
    """
  end
end
