defmodule SpGen.Blueprint.EventTest do
  @moduledoc """
  The event's own test file (`events/<event>_test.exs`): a `describe "Event"`
  block exercising construction, enforced fields, and JSON serialization.

  The event, not the operation, is what is tested here — the fact is the unit
  of behaviour, so the aggregate's `describe "Aggregate"` and the projector's
  `describe "Projector"` for the same event live in this file too
  (`SpGen.Blueprint.AggregateTest`, `SpGen.Blueprint.ProjectorTest`).
  """

  use SpGen.Blueprint

  alias SpGen.Templates
  alias SpGen.Blueprint.{Event, TestCaseFile}

  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/events/<_event>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>Test"

  def plans(%Context{} = ctx) do
    [
      TestCaseFile.plan(ctx,
        path: @test_path,
        module: @test_module,
        alias_templates: [Event.module_template()],
        requires: fn c -> [{Event.module_file(c), "event not generated (spgen event)"}] end,
        describes: [{"Event", &describe_body/2, ["<Event> event"]}]
      )
    ]
  end

  @doc false
  def describe_body(ctx, subject) do
    event = Context.render("<Event>", ctx)
    body = Templates.struct_body(ctx)

    tests = [
      """
      test "creates #{event} with required fields" do
        event = struct!(#{event}, %{#{body}})

        assert event.id != nil
      end
      """,
      """
      test "requires enforced fields" do
        assert_raise ArgumentError, fn ->
          struct!(#{event}, %{})
        end
      end
      """,
      """
      test "serializes to JSON" do
        event = struct!(#{event}, %{#{body}})

        assert {:ok, _json} = Jason.encode(event)
      end
      """
    ]

    """
    describe "#{subject}" do
    #{tests |> Enum.join("\n\n") |> Templates.indent(2)}
    end
    """
  end
end
