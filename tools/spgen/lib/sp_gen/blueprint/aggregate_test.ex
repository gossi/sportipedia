defmodule SpGen.Blueprint.AggregateTest do
  @moduledoc """
  The aggregate's contribution to each event's test file
  (`events/<event>_test.exs`): a `describe "Aggregate"` block applying that
  event to the state — the fact under test decides where its test lives, so
  every event of the aggregate gets its own apply test in its own file.
  """

  use SpGen.Blueprint

  alias SpGen.{Context, Esdm, Templates}
  alias SpGen.Blueprint.{Aggregate, Event, TestCaseFile}

  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/events/<_event>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>Test"

  def plans(%Context{} = ctx) do
    ctx
    |> Context.aggregate_events()
    |> Enum.map(fn event -> plan_for_event(ctx, event) end)
  end

  defp plan_for_event(%Context{} = ctx, %Element{} = event) do
    event_ctx = %{ctx | element: event}

    TestCaseFile.plan(ctx,
      path: @test_path,
      module: @test_module,
      extra_vars: %{"event" => event.name},
      alias_templates: [Aggregate.module_template()],
      alias_modules: [Context.render(Event.module_template(), event_ctx)],
      requires: fn c ->
        [
          {Aggregate.module_file(c), "aggregate not generated (spgen aggregate)"},
          {Event.module_file(event_ctx),
           "event #{event.name} not generated (spgen event #{event.name})"}
        ]
      end,
      describes: [
        {"Aggregate", fn c, subject -> describe_body(c, subject, [event]) end,
         ["<DomainObject>Aggregate"]}
      ]
    )
  end

  @doc false
  def describe_body(ctx, subject, events) do
    aggregate = Context.render("<DomainObject>Aggregate", ctx)

    tests =
      Enum.map(events, fn e ->
        event_pascal = Context.pascal(e.name)

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
