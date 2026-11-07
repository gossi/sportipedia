defmodule Sportipedia.Catalog.Equipment.Instrument.Operation.InstrumentArchivedTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentArchived
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentAggregate
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentProjector
  alias Sportipedia.Catalog.Repo

  describe "Event" do
    @describetag :unit

    test "struct has enforced id field" do
      assert_raise ArgumentError, ~r"keys must also be given", fn ->
        struct!(InstrumentArchived, %{})
      end
    end

    test "can be encoded to JSON" do
      event = %InstrumentArchived{id: "e-2"}

      encoded = Jason.encode!(event)

      assert encoded =~ ~s("id":"e-2")
    end
  end

  describe "Aggregate" do
    @describetag :unit

    test "applies InstrumentArchived event, returning nil" do
      event = %InstrumentArchived{id: "agg-1"}

      result = InstrumentAggregate.apply(%InstrumentAggregate{}, event)

      assert result == nil
    end
  end

  describe "Projector" do
    @describetag :integration

    test "deletes the instrument read model on InstrumentArchived event" do
      id = UUID.uuid4()

      Repo.insert!(%InstrumentReadModel{id: id, title: "Unicycle", slug: "unicycle"})

      event = %InstrumentArchived{id: id}

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
      refute Repo.get(InstrumentReadModel, id)
    end

    test "is idempotent for the same event" do
      id = UUID.uuid4()

      Repo.insert!(%InstrumentReadModel{id: id, title: "Unicycle", slug: "unicycle"})

      event = %InstrumentArchived{id: id}

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

      assert Repo.all(InstrumentReadModel) == []
    end

    test "is a no-op when instrument does not exist" do
      event = %InstrumentArchived{id: UUID.uuid4()}

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
    end
  end
end
