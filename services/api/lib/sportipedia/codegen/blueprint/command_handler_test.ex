defmodule Sportipedia.Codegen.Blueprint.CommandHandlerTest do
  @moduledoc """
  The command handler's contribution to the operation test file: a
  `describe "<Command>Handler"` block exercising `handle/2` with a sample
  command and asserting the emitted event.
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.Templates
  alias Sportipedia.Codegen.Blueprint.{CommandHandler, OperationTest}

  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Command>Test"

  def plans(%Context{} = ctx) do
    [
      OperationTest.plan(ctx,
        path: @test_path,
        module: @test_module,
        alias_templates: [
          CommandHandler.command_template(),
          CommandHandler.module_template(),
          CommandHandler.event_template(),
          CommandHandler.aggregate_template()
        ],
        describes: [{"<Command>Handler", &describe_body/2}]
      )
    ]
  end

  @doc false
  def describe_body(ctx, subject) do
    command = Context.render("<Command>", ctx)
    handler = command <> "Handler"
    event = CommandHandler.event_render(ctx)
    aggregate = Context.render("<DomainObject>Aggregate", ctx)

    body =
      ctx.fields
      |> Enum.map(fn f -> "#{f.name}: #{Templates.sample_value(ctx, f)}" end)
      |> Enum.join(", ")

    """
    describe "#{subject}" do
      test "handles #{command} command and returns #{event} event" do
        cmd = %#{command}{#{body}}

        events = #{handler}.handle(%#{aggregate}{}, cmd)

        assert %#{event}{} = events
      end
    end
    """
  end
end
