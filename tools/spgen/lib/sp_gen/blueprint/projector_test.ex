defmodule SpGen.Blueprint.ProjectorTest do
  @moduledoc """
  The projector's contribution to its event's test file
  (`events/<event>_test.exs`): a `describe "Projector"` block running `handle/2`
  with a fully populated metadata map and asserting the projected row — the
  projection of a fact is tested where the fact is tested.
  """

  use SpGen.Blueprint

  alias SpGen.{Esdm, Templates}
  alias SpGen.Blueprint.{Event, Projector, ReadModel, TestCaseFile}

  @test_path "services/api/test/sportipedia/<_subdomain>/<composite>/<domain_object>/events/<_event>_test.exs"
  @test_module "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>Test"

  def plans(%Context{} = ctx) do
    plain = Context.render("<DomainObject>Projector", ctx)

    [
      TestCaseFile.plan(ctx,
        path: @test_path,
        module: @test_module,
        alias_templates: [Projector.module_template(), ReadModel.module_template()],
        alias_modules: seed_modules(ctx),
        requires: fn c ->
          [
            {Projector.module_file(c), "projector not generated (spgen projector)"},
            {Event.module_file(c), "event not generated (spgen event)"},
            {ReadModel.module_file(c), "read model not generated (spgen read_model)"}
          ]
        end,
        describes: [{"Projector", &describe_body/2, ["<DomainObject>Projector - <Event>", plain]}]
      )
    ]
  end

  @doc false
  def describe_body(ctx, subject) do
    projector = Context.render("<DomainObject>Projector", ctx)
    event_pascal = Context.pascal(ctx.element.name)
    read_model = Context.pascal(ctx.constituent) <> "ReadModel"
    # update/delete projections need existing state: the golden pattern
    # projects the citizen's create event first
    case Context.effect_for_event(ctx, ctx.element.name) do
      :create ->
        body = Templates.struct_body(ctx)
        block(subject, projector, event_pascal, read_model, body, nil, ctx, "!= nil")

      effect ->
        with seed when not is_nil(seed) <- create_seed(ctx) do
          block(
            subject,
            projector,
            event_pascal,
            read_model,
            seed_body(ctx, true),
            seed,
            ctx,
            outcome(effect, read_model)
          )
        else
          _ ->
            body = Templates.struct_body(ctx)
            block(subject, projector, event_pascal, read_model, body, nil, ctx, "!= nil")
        end
    end
  end

  # the seed projects the citizen's create event, so its module is referenced
  defp seed_modules(ctx) do
    case Context.effect_for_event(ctx, ctx.element.name) do
      :create ->
        []

      _ ->
        case create_event(ctx) do
          nil -> []
          e -> [Context.render(Event.module_template(), %{ctx | element: e})]
        end
    end
  end

  defp create_event(ctx) do
    ctx.model
    |> Esdm.events_of(ctx.constituent)
    |> Enum.find(fn e -> Context.effect_for_event(ctx, e.name) == :create end)
  end

  defp outcome(:delete, _read_model), do: "== nil"
  defp outcome(_effect, _read_model), do: "!= nil"

  # the aggregate's create event (the row the projection starts from)
  defp create_seed(ctx) do
    create_event(ctx)
    |> case do
      nil ->
        nil

      e ->
        pascal = Context.pascal(e.name)
        fields = Esdm.fields(e)

        literal =
          fields
          |> Enum.map(fn f -> "#{f.name}: #{Templates.sample_value(ctx, f)}" end)
          |> Enum.join(", ")

        """
        create_event = %#{pascal}{#{literal}}

        #{metadata(ctx, "create_metadata", "create_event", 1)}
        assert :ok = #{Context.render("<DomainObject>Projector", ctx)}.handle(create_event, create_metadata)
        """
    end
  end

  defp metadata(ctx, var, event_var, number) do
    """
    #{var} = %{
      handler_name: "#{Projector.projection_name(ctx)}",
      event_number: #{number},
      event_id: UUID.uuid4(),
      stream_id: "#{ctx.constituent}-\#{#{event_var}.id}",
      stream_version: #{number},
      correlation_id: nil,
      causation_id: nil,
      created_at: DateTime.utc_now(),
      application: Sportipedia.#{Context.pascal(ctx.subdomain)},
      state: nil
    }
    """
  end

  # the event under test continues the seeded stream: same id
  defp seed_body(ctx, seeded?) do
    if seeded? do
      Templates.struct_body(ctx, %{"id" => "create_event.id"})
    else
      Templates.struct_body(ctx)
    end
  end

  defp block(subject, projector, event_pascal, read_model, body, seed, ctx, outcome) do
    event_part =
      if seed do
        """
        #{seed}
        event = %#{event_pascal}{#{body}}

        #{metadata(ctx, "metadata", "event", 2)}
        """
      else
        """
        event = %#{event_pascal}{#{body}}

        #{metadata(ctx, "metadata", "event", 1)}
        """
      end

    """
    describe "#{subject}" do
      test "projects #{event_pascal} to the #{ctx.constituent} read model" do
    #{[event_part, "assert :ok = #{projector}.handle(event, metadata)", "", "assert Repo.get(#{read_model}, event.id) #{outcome}"] |> Enum.join("\n") |> Templates.indent(4)}
      end
    end
    """
  end
end
