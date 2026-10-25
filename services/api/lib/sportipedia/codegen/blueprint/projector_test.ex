defmodule Sportipedia.Codegen.Blueprint.ProjectorTest do
  @moduledoc """
  The projector's contribution to the operation test file(s) of the commands
  publishing its event: a `describe "<DomainObject>Projector - <Event>"`
  block running `handle/2` with a fully populated metadata map and asserting
  the projected row.
  """

  use Sportipedia.Codegen.Blueprint

  alias Sportipedia.Codegen.{Esdm, Templates}
  alias Sportipedia.Codegen.Blueprint.{OperationTest, Projector}

  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/operation/<_operation>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Command>Test"

  # the projector's tests live in the operation test file(s) of the commands
  # publishing this event
  def plans(%Context{} = ctx) do
    publishers =
      ctx.model.elements
      |> Enum.filter(fn el -> el.kind == :command and ctx.element.name in Esdm.publishes(el) end)
      |> Enum.sort_by(& &1.name)

    plain = Context.render("<DomainObject>Projector", ctx)

    Enum.map(publishers, fn command ->
      OperationTest.plan(ctx,
        path: @test_path,
        module: @test_module,
        extra_vars: %{"operation" => command.name, "command" => command.name},
        alias_templates: [Projector.module_template()],
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
          handler_name: "#{Projector.projection_name(ctx)}",
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
