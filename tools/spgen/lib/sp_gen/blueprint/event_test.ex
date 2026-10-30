defmodule SpGen.Blueprint.EventTest do
  @moduledoc """
  The event's contribution to the operation test file(s) of the command(s)
  publishing it: a `describe "<Event> event"` block exercising construction,
  enforced fields, and JSON serialization.
  """

  use SpGen.Blueprint

  alias SpGen.Templates
  alias SpGen.Blueprint.{Event, OperationTest}

  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Command>Test"

  def plans(%Context{} = ctx) do
    ctx
    |> Context.publishing_commands()
    |> Enum.map(fn command ->
      extra_vars = %{"operation" => command.name, "command" => command.name}

      OperationTest.plan(ctx,
        path: @test_path,
        module: @test_module,
        extra_vars: extra_vars,
        alias_templates: [Event.module_template()],
        requires: fn c -> [{Event.module_file(c), "event not generated (spgen event)"}] end,
        describes: [{"<Event> event", &describe_body/2}]
      )
    end)
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
