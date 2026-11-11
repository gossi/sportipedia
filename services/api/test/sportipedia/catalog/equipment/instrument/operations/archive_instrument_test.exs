defmodule Sportipedia.Catalog.Equipment.Instrument.Operation.ArchiveInstrumentTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Instrument
  alias Sportipedia.Catalog.Equipment.Instrument.Policy
  alias Sportipedia.Catalog.Equipment.Instrument.Command.ArchiveInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.Command.ArchiveInstrumentHandler
  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentArchived
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentAggregate
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  alias Sportipedia.Catalog.Repo

  import Sportipedia.TestSupport.Catalog.Equipment

  alias Sportipedia.TestSupport.Catalog.Equipment.InstrumentFixtures

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

    test "creates command with required id field" do
      id = UUID.uuid4()
      cmd = %ArchiveInstrument{id: id}

      assert cmd.id == id
    end

    @tag :integration
    test "is valid with id" do
      instrument = InstrumentFixtures.unicycle()

      new_instrument(instrument)

      cmd = %ArchiveInstrument{id: instrument.id}

      assert Vex.valid?(cmd)
    end

    test "requires id field" do
      assert_raise ArgumentError, fn ->
        struct!(ArchiveInstrument, %{})
      end
    end

    test "id cannot be nil" do
      cmd = %ArchiveInstrument{id: nil}

      assert_raise ArgumentError, fn ->
        Vex.validate(cmd)
      end
    end

    test "is invalid when id does not exist" do
      cmd = ArchiveInstrument.new(id: UUID.uuid4())

      assert {:error, [{:error, :id, :by, :not_found}]} = Vex.validate(cmd)
    end

    @tag :integration
    test "is valid when id exists" do
      instrument = InstrumentFixtures.unicycle()

      new_instrument(instrument)

      cmd = %ArchiveInstrument{id: instrument.id}

      assert {:ok, _} = Vex.validate(cmd)
    end
  end

  describe "Handler" do
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

  describe "Public API" do
    @describetag :integration

    test "dispatches ArchiveInstrument through the router" do
      instrument = InstrumentFixtures.unicycle()

      new_instrument(instrument)

      cmd = ArchiveInstrument.new(id: instrument.id)

      assert :ok = Sportipedia.Catalog.dispatch(cmd, consistency: :strong)
      refute Repo.get(InstrumentReadModel, instrument.id)
    end

    test "archive_instrument/1 archives through the public API" do
      params = %{title: "Unicycle", slug: "unicycle", description: "Best vehicle in the world"}

      assert {:ok, instrument} = Instrument.catalog_instrument(params)
      assert :ok = Instrument.archive_instrument(instrument.id)
      refute Repo.get(InstrumentReadModel, instrument.id)
    end

    test "returns error for non-existent apparatus" do
      id = UUID.uuid4()

      # This should still succeed at dispatch level (event sourcing allows archiving non-existent)
      # but the read model won't exist
      assert {:error, :not_found} = Instrument.archive_instrument(id)
    end
  end
end
