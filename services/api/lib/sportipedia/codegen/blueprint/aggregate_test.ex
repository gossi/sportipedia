defmodule Sportipedia.Codegen.Blueprint.AggregateTest do
  @moduledoc """
  The aggregate's contribution to the operation test file(s)
  (`operation-test.md`): one `describe "<DomainObject>Aggregate"` block per
  publishing command's test file, applying every event of the aggregate to
  the state.
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.{Context, Esdm, Templates}
  alias Sportipedia.Codegen.Blueprint.{Aggregate, OperationTest}

  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Command>Test"

  # the aggregate's tests live in every publishing command's operation test
  def plans(%Context{} = ctx) do
    Esdm.events_of(ctx.model, ctx.constituent)
    |> Enum.flat_map(fn e -> publishers(ctx, e.name) end)
    |> Enum.uniq()
    |> Enum.map(fn command_name ->
      OperationTest.plan(ctx,
        path: @test_path,
        module: @test_module,
        extra_vars: %{"operation" => command_name, "command" => command_name},
        alias_templates: [Aggregate.module_template()],
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
