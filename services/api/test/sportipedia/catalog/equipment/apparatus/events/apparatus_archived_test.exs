defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.ApparatusArchivedTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusArchived
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector

  describe "Event" do
    @describetag :unit

    test "creates event with required id field" do
      id = UUID.uuid4()
      event = %ApparatusArchived{id: id}

      assert event.id == id
    end

    test "requires id field" do
      assert_raise ArgumentError, fn ->
        struct!(ApparatusArchived, %{})
      end
    end

    test "serializes to JSON" do
      id = UUID.uuid4()
      event = %ApparatusArchived{id: id}

      json = Jason.encode!(event)
      assert Jason.decode!(json)["id"] == id
    end
  end

  describe "Aggregate" do
    @describetag :unit

    test "applies ApparatusArchived to aggregate state" do
      id = UUID.uuid4()

      event = %ApparatusArchived{id: id}

      aggregate = %ApparatusAggregate{
        id: id,
        title: "Vaulting Table",
        slug: "vaulting-table"
      }

      result = ApparatusAggregate.apply(aggregate, event)

      assert result == nil
    end
  end

  describe "Projector" do
    @describetag :integration

    test "projects ApparatusArchived event by hard-deleting read model" do
      # First, create an apparatus via catalog
      catalog_event = %Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      catalog_metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "apparatus-#{catalog_event.id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(catalog_event, catalog_metadata)

      # Verify it exists
      assert Repo.get(ApparatusReadModel, catalog_event.id) != nil

      # Now archive it
      archive_event = %ApparatusArchived{id: catalog_event.id}

      archive_metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 2,
        event_id: UUID.uuid4(),
        stream_id: "apparatus-#{catalog_event.id}",
        stream_version: 2,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(archive_event, archive_metadata)

      # Verify it's hard-deleted
      assert Repo.get(ApparatusReadModel, catalog_event.id) == nil
    end

    test "is idempotent - archiving non-existent record is safe" do
      id = UUID.uuid4()
      event = %ApparatusArchived{id: id}

      metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 3,
        event_id: UUID.uuid4(),
        stream_id: "apparatus-#{id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(event, metadata)
    end
  end
end
