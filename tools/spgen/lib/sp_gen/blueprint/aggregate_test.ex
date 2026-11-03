defmodule SpGen.Blueprint.AggregateTest do
  @moduledoc """
  The aggregate's contribution to the operation test file(s)
  (`operation-test.md`): one `describe "<DomainObject>Aggregate"` block per
  publishing command's test file, applying every event of the aggregate to
  the state.
  """

  use SpGen.Blueprint

  alias SpGen.{Context, Esdm, Templates}
  alias SpGen.Blueprint.{Aggregate, Event, OperationTest}

  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Command>Test"

  # the aggregate's tests live in every publishing command's operation test;
  # each file applies the events that command publishes (golden shape)
  def plans(%Context{} = ctx) do
    Esdm.events_of(ctx.model, ctx.constituent)
    |> Enum.flat_map(fn e -> publishers(ctx, e.name) end)
    |> Enum.uniq()
    |> Enum.map(fn command_name ->
      command_events = published_events(ctx, command_name)

      OperationTest.plan(ctx,
        path: @test_path,
        module: @test_module,
        extra_vars: %{"operation" => command_name, "command" => command_name},
        alias_templates: [Aggregate.module_template()],
        alias_modules: event_modules(ctx, command_events),
        requires: fn c ->
          [{Aggregate.module_file(c), "aggregate not generated (spgen aggregate)"}] ++
            for(
              e <- command_events,
              do:
                {Event.module_file(%{c | element: e}),
                 "event #{e.name} not generated (spgen event #{e.name})"}
            )
        end,
        describes: [
          {"<DomainObject>Aggregate",
           fn c, subject -> describe_body(c, subject, command_events) end}
        ]
      )
    end)
  end

  defp published_events(ctx, command_name) do
    with {:ok, command} <- Esdm.find(ctx.model, :command, command_name) do
      command
      |> Esdm.publishes()
      |> Enum.map(
        &Enum.find(Esdm.events_of(ctx.model, ctx.constituent), fn e -> e.name == &1 end)
      )
      |> Enum.reject(&is_nil/1)
    else
      _ -> []
    end
  end

  # the describe applies the command's events, so those event modules
  # need an alias here
  defp event_modules(ctx, events) do
    Enum.map(events, fn e -> Context.render(Event.module_template(), %{ctx | element: e}) end)
  end

  defp publishers(ctx, event_name) do
    ctx.model.elements
    |> Enum.filter(fn el -> el.kind == :command and event_name in Esdm.publishes(el) end)
    |> Enum.map(& &1.name)
  end

  @doc false
  def describe_body(ctx, subject, events) do
    aggregate = Context.render("<DomainObject>Aggregate", ctx)

    tests =
      Enum.map(events, fn e ->
        event_pascal =
          e.name |> String.split("-") |> Enum.map(&String.capitalize/1) |> Enum.join()

        # the literal carries the EVENT's fields; the state it is applied to is
        # seeded with the id so update/delete clauses have something to act on
        fields = Esdm.fields(e)

        event_body =
          fields
          |> Enum.map(fn f -> "#{f.name}: #{Templates.sample_value(ctx, f)}" end)
          |> Enum.join(", ")

        """
        test "applies #{e.name} to aggregate state" do
          event = %#{event_pascal}{#{event_body}}

          #{apply_test(ctx, aggregate, e, fields)}
        end
        """
      end)

    """
    describe "#{subject}" do
    #{tests |> Enum.join("\n\n") |> Templates.indent(2)}
    end
    """
  end

  defp apply_test(ctx, aggregate, e, fields) do
    seed = "%#{aggregate}{id: event.id}"

    case Context.effect_for_event(ctx, e.name) do
      :create ->
        """
        result = #{aggregate}.apply(%#{aggregate}{}, event)

        #{assertions(fields)}
        """

      :delete ->
        """
        result = #{aggregate}.apply(#{seed}, event)

        assert is_nil(result)
        """

      :update ->
        """
        result = #{aggregate}.apply(#{seed}, event)

        #{assertions(fields)}
        """
    end
  end

  defp assertions(fields) do
    fields
    |> Enum.map(fn f -> "assert result.#{f.name} == event.#{f.name}" end)
    |> Enum.join("\n      ")
  end
end
