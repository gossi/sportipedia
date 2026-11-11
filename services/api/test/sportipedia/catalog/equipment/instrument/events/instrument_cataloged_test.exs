defmodule Sportipedia.Catalog.Equipment.Instrument.Feature.InstrumentCatalogedTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentCataloged
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentAggregate
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentProjector
  alias Sportipedia.Catalog.Repo

  import Sportipedia.TestSupport.Catalog.Equipment

  alias Sportipedia.TestSupport.Catalog.Equipment.InstrumentFixtures

  describe "Event" do
    @describetag :unit

    test "struct has enforced fields" do
      assert_raise ArgumentError, ~r"keys must also be given", fn ->
        struct!(InstrumentCataloged, %{})
      end
    end

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
    @describetag :unit

    test "applies InstrumentCataloged event to aggregate state" do
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

    test "id is propagated from event to aggregate state" do
      event = %InstrumentCataloged{id: "agg-id", title: "Beam", slug: "beam"}

      result = InstrumentAggregate.apply(%InstrumentAggregate{}, event)

      assert result.id == "agg-id"
    end
  end

  describe "Projector" do
    @describetag :integration

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

    test "rejects duplicate slug" do
      new_instrument(InstrumentFixtures.unicycle())

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

      assert {:error, _} = InstrumentProjector.handle(event, metadata)
    end
  end
end
