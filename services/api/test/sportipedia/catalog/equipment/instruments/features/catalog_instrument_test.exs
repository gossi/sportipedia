defmodule Sportipedia.Catalog.Equipment.Instruments.Feature.CatalogInstrumentTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Instruments
  alias Sportipedia.Catalog.Equipment.Instruments.Policy
  alias Sportipedia.Catalog.Equipment.Instruments.Command.CatalogInstrument
  alias Sportipedia.Catalog.Equipment.Instruments.Command.CatalogInstrumentHandler
  alias Sportipedia.Catalog.Equipment.Instruments.Event.InstrumentCataloged
  alias Sportipedia.Catalog.Equipment.Instruments.InstrumentAggregate
  alias Sportipedia.Catalog.Equipment.Instruments.InstrumentReadModel
  alias Sportipedia.Catalog.Equipment.Instruments.InstrumentProjector
  alias Sportipedia.Catalog.Repo

  describe "Policy" do
    @tag :unit
    test "allows authenticated user to catalog an instrument" do
      assert Policy.authorize(:catalog_instrument, %{id: "user-123"}, %{}) == :ok
    end

    @tag :unit
    test "rejects unauthenticated user" do
      assert Policy.authorize(:catalog_instrument, nil, %{}) == :error
    end
  end

  describe "Command" do
    @tag :unit
    test "is valid with all required fields" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), title: "Tennis Racket", slug: "tennis-racket")

      assert Vex.valid?(cmd)
    end

    @tag :unit
    test "is invalid without title" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), slug: "tennis-racket")

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :title, _, _}, &1))
    end

    @tag :unit
    test "is invalid without slug" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), title: "Tennis Racket")

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :slug, _, _}, &1))
    end

    @tag :unit
    test "is valid when description is omitted" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), title: "Tennis Racket", slug: "tennis-racket")

      assert Vex.valid?(cmd)
    end

    @tag :integration
    test "is invalid with duplicate slug" do
      slug = "tennis-racket"

      InstrumentReadModel.insert_changeset(%{id: UUID.uuid4(), title: "Existing", slug: slug})
      |> Repo.insert!()

      cmd = CatalogInstrument.new(id: UUID.uuid4(), title: "Tennis Racket", slug: slug)

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :slug, _, "slug already exists"}, &1))
    end
  end

  describe "Command Handler" do
    @tag :unit
    test "creates InstrumentCataloged event from CatalogInstrument command" do
      cmd =
        CatalogInstrument.new(
          id: "cmd-1",
          title: "Unicycle",
          slug: "unicycle",
          description: "Best vehicle in the world"
        )

      aggregate = %InstrumentAggregate{}

      assert %InstrumentCataloged{
               id: "cmd-1",
               title: "Unicycle",
               slug: "unicycle",
               description: "Best vehicle in the world"
             } = CatalogInstrumentHandler.handle(aggregate, cmd)
    end

    @tag :unit
    test "copies all fields from command to event" do
      cmd =
        CatalogInstrument.new(
          id: "cmd-2",
          title: "Skateboard",
          slug: "skateboard",
          description: "desc"
        )

      event = CatalogInstrumentHandler.handle(%InstrumentAggregate{}, cmd)

      assert event.id == cmd.id
      assert event.title == cmd.title
      assert event.slug == cmd.slug
      assert event.description == cmd.description
    end
  end

  describe "Event" do
    @tag :unit
    test "struct has all enforced fields" do
      event = %InstrumentCataloged{id: "e-1", title: "Hockey Stick", slug: "hockey-stick"}

      assert event.title == "Hockey Stick"
      assert event.slug == "hockey-stick"
    end

    @tag :unit
    test "can be encoded to JSON" do
      event = %InstrumentCataloged{
        id: "e-2",
        title: "Unicycle",
        slug: "unicycle",
        description: "Best vehicle in the world"
      }

      encoded = Jason.encode!(event)

      assert encoded =~ ~s("title":"Unicycle")
      assert encoded =~ ~s("slug":"unicycle")
      assert encoded =~ ~s("description":"Best vehicle in the world")
    end
  end

  describe "Aggregate" do
    @tag :unit
    test "creates aggregate state from InstrumentCataloged event" do
      event = %InstrumentCataloged{
        id: "agg-1",
        title: "Unicycle",
        slug: "unicycle",
        description: "Best vehicle in the world"
      }

      result = InstrumentAggregate.apply(%InstrumentAggregate{}, event)

      assert result.title == "Unicycle"
      assert result.slug == "unicycle"
      assert result.description == "Best vehicle in the world"
    end

    @tag :unit
    test "id is not propagated from event to aggregate state" do
      event = %InstrumentCataloged{id: "agg-id", title: "Beam", slug: "beam"}

      result = InstrumentAggregate.apply(%InstrumentAggregate{}, event)

      assert result.id == "agg-id"
    end
  end

  describe "Projector" do
    @tag :integration
    test "projects InstrumentCataloged event into the read model" do
      event = %InstrumentCataloged{
        id: UUID.uuid4(),
        title: "Unicycle",
        slug: "unicycle",
        description: "Best vehicle in the world"
      }

      metadata = %{
        handler_name: "equipment.instrument_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "instrument-#{event.id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = InstrumentProjector.handle(event, metadata)

      instrument = Repo.get!(InstrumentReadModel, event.id)
      assert instrument.title == "Unicycle"
      assert instrument.slug == "unicycle"
      assert instrument.description == "Best vehicle in the world"
    end

    @tag :integration
    test "is idempotent for the same event" do
      event = %InstrumentCataloged{
        id: UUID.uuid4(),
        title: "Unicycle",
        slug: "unicycle"
      }

      metadata = %{
        handler_name: "equipment.instrument_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "instrument-#{event.id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = InstrumentProjector.handle(event, metadata)
      assert :ok = InstrumentProjector.handle(event, metadata)

      assert [instrument] = Repo.all(InstrumentReadModel)
      assert instrument.id == event.id
    end

    @tag :integration
    test "rejects duplicate slug" do
      slug = "unicycle"

      Repo.insert!(%InstrumentReadModel{id: UUID.uuid4(), title: "Existing", slug: slug})

      event = %InstrumentCataloged{
        id: UUID.uuid4(),
        title: "Unicycle",
        slug: slug
      }

      metadata = %{
        handler_name: "equipment.instrument_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "instrument-#{event.id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert {:error, _} = InstrumentProjector.handle(event, metadata)
    end
  end

  describe "End-to-end" do
    @tag :integration
    test "dispatches CatalogInstrument through the router" do
      id = UUID.uuid4()
      cmd = CatalogInstrument.new(id: id, title: "Unicycle", slug: "unicycle")

      assert :ok = Sportipedia.Catalog.dispatch(cmd, consistency: :strong)

      assert %InstrumentReadModel{title: "Unicycle", slug: "unicycle"} =
               Repo.get(InstrumentReadModel, id)
    end

    @tag :integration
    test "validation failure is rejected before reaching the aggregate" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), slug: "unicycle")

      assert {:error, {:validation_failure, %{title: ["must be present"]}}} =
               Sportipedia.Catalog.dispatch(cmd)
    end

    @tag :integration
    test "catalog_instrument/1 creates an instrument through the public API" do
      params = %{
        title: "Unicycle",
        slug: "unicycle",
        description: "Best vehicle in the world"
      }

      assert {:ok, instrument} = Instruments.catalog_instrument(params)
      assert instrument.title == "Unicycle"
      assert instrument.slug == "unicycle"
      assert instrument.description == "Best vehicle in the world"
      assert is_binary(instrument.id)
    end
  end
end
