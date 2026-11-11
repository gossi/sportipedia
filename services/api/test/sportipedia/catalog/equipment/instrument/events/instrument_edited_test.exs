defmodule Sportipedia.Catalog.Equipment.Instrument.Feature.InstrumentEditedTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentEdited
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentAggregate
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentProjector
  alias Sportipedia.Catalog.Repo

  import Sportipedia.TestSupport.Catalog.Equipment

  describe "Event" do
    @describetag :unit

    test "struct has enforced id field" do
      assert_raise ArgumentError, ~r"keys must also be given", fn ->
        struct!(InstrumentEdited, %{})
      end
    end

    test "can be encoded to JSON" do
      event = %InstrumentEdited{
        id: "e-1",
        title: "Unicycle",
        slug: "unicycle",
        description: "Best vehicle in the world"
      }

      encoded = Jason.encode!(event)

      assert encoded =~ ~s("title":"Unicycle")
      assert encoded =~ ~s("slug":"unicycle")
      assert encoded =~ ~s("description":"Best vehicle in the world")
    end

    test "changes only include modified fields" do
      event = %InstrumentEdited{id: "e-1", title: "Unicycle"}
      changes = InstrumentEdited.get_changes(event)

      assert Map.has_key?(changes, :title)
      refute Map.has_key?(changes, :slug)
      refute Map.has_key?(changes, :description)

      assert changes.title == "Unicycle"
    end

    test "encodes only non-nil fields" do
      event = %InstrumentEdited{id: "e-1", title: "Unicycle"}

      encoded = Jason.encode!(event)

      assert encoded =~ ~s("title":"Unicycle")
      refute encoded =~ ~s("slug")
      refute encoded =~ ~s("description")
    end
  end

  describe "Aggregate" do
    @describetag :unit

    test "applies InstrumentEdited event to aggregate state" do
      aggregate = %InstrumentAggregate{
        id: "agg-1",
        title: "Old Title",
        slug: "old-slug",
        description: "Old description"
      }

      event = %InstrumentEdited{id: "agg-1", title: "New Title"}

      result = InstrumentAggregate.apply(aggregate, event)

      assert result.title == "New Title"
      assert result.slug == "old-slug"
      assert result.description == "Old description"
    end

    test "partially updates only the changed fields" do
      aggregate = %InstrumentAggregate{
        id: "agg-1",
        title: "Old Title",
        slug: "old-slug",
        description: "Old description"
      }

      event = %InstrumentEdited{id: "agg-1", slug: "new-slug", description: "New description"}

      result = InstrumentAggregate.apply(aggregate, event)

      assert result.title == "Old Title"
      assert result.slug == "new-slug"
      assert result.description == "New description"
    end

    test "preserves id from existing aggregate" do
      aggregate = %InstrumentAggregate{
        id: "agg-1",
        title: "Old Title",
        slug: "old-slug",
        description: nil
      }

      event = %InstrumentEdited{id: "agg-1", title: "New Title"}

      result = InstrumentAggregate.apply(aggregate, event)

      assert result.id == "agg-1"
    end
  end

  describe "Projector" do
    @describetag :integration

    test "updates the instrument read model on InstrumentEdited event" do
      id = UUID.uuid4()

      new_instrument(%{id: id, title: "Original", slug: "original", description: "desc"})

      event = %InstrumentEdited{
        id: id,
        title: "Updated",
        slug: "updated",
        description: "new desc"
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

      instrument = Repo.get!(InstrumentReadModel, id)
      assert instrument.title == "Updated"
      assert instrument.slug == "updated"
      assert instrument.description == "new desc"
    end

    test "partially updates leaving other fields intact" do
      id = UUID.uuid4()

      new_instrument(%{id: id, title: "Original", slug: "original", description: "desc"})

      event = %InstrumentEdited{id: id, description: "new desc"}

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

      instrument = Repo.get!(InstrumentReadModel, id)
      assert instrument.title == "Original"
      assert instrument.slug == "original"
      assert instrument.description == "new desc"
    end

    test "does nothing when instrument does not exist" do
      event = %InstrumentEdited{id: UUID.uuid4(), title: "Updated"}

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

    test "is idempotent for the same event" do
      id = UUID.uuid4()

      new_instrument(%{id: id, title: "Original", slug: "original"})

      event = %InstrumentEdited{id: id, title: "Updated"}

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
      assert instrument.id == id
      assert instrument.title == "Updated"
    end

    test "rejects duplicate slug" do
      new_instrument(%{id: UUID.uuid4(), title: "Existing", slug: "existing"})

      id = UUID.uuid4()
      new_instrument(%{id: id, title: "Original", slug: "original"})

      event = %InstrumentEdited{id: id, slug: "existing"}

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
