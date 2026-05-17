defmodule Sportipedia.Catalog.Equipment.Instrument.Feature.ArchiveInstrumentTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Instrument
  alias Sportipedia.Catalog.Equipment.Instrument.Policy
  alias Sportipedia.Catalog.Equipment.Instrument.Command.ArchiveInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.Command.ArchiveInstrumentHandler
  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentArchived
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentAggregate
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentProjector
  alias Sportipedia.Catalog.Repo

  describe "Policy" do
    @describetag :unit

    test "allows authenticated user to archive an instrument" do
      assert Policy.authorize(:archive_instrument, %{id: "user-123"}, %{}) == :ok
    end

    test "rejects unauthenticated user" do
      assert Policy.authorize(:archive_instrument, nil, %{}) == :error
    end
  end

  describe "Command" do
    @describetag :unit

    test "is valid with id" do
      cmd = ArchiveInstrument.new(id: UUID.uuid4())

      assert Vex.valid?(cmd)
    end

    test "raises when required struct fields are missing" do
      assert_raise ArgumentError, ~r"keys must also be given", fn ->
        struct!(ArchiveInstrument, %{})
      end
    end

    test "is invalid without id" do
      cmd = ArchiveInstrument.new(id: nil)

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :id, _, _}, &1))
    end
  end

  describe "Command Handler" do
    @describetag :unit

    test "creates InstrumentArchived event from ArchiveInstrument command" do
      cmd = ArchiveInstrument.new(id: "cmd-1")

      assert %InstrumentArchived{id: "cmd-1"} =
               ArchiveInstrumentHandler.handle(%InstrumentAggregate{}, cmd)
    end

    test "copies id from command to event" do
      cmd = ArchiveInstrument.new(id: "cmd-2")

      event = ArchiveInstrumentHandler.handle(%InstrumentAggregate{}, cmd)

      assert event.id == cmd.id
    end
  end

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

  describe "Public API" do
    @describetag :integration

    test "dispatches ArchiveInstrument through the router" do
      id = UUID.uuid4()

      Repo.insert!(%InstrumentReadModel{id: id, title: "Unicycle", slug: "unicycle"})

      cmd = ArchiveInstrument.new(id: id)

      assert :ok = Sportipedia.Catalog.dispatch(cmd, consistency: :strong)
      refute Repo.get(InstrumentReadModel, id)
    end

    test "validation failure is rejected before reaching the aggregate" do
      cmd = ArchiveInstrument.new(id: nil)

      assert {:error, {:validation_failure, %{id: ["must be present"]}}} =
               Sportipedia.Catalog.dispatch(cmd)
    end

    test "archive_instrument/1 archives through the public API" do
      params = %{title: "Unicycle", slug: "unicycle", description: "Best vehicle in the world"}

      assert {:ok, instrument} = Instrument.catalog_instrument(params)
      assert :ok = Instrument.archive_instrument(instrument.id)
      refute Instrument.instrument_by_id(instrument.id)
    end
  end
end
