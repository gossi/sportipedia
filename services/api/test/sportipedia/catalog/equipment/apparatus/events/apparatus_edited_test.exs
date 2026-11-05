defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.ApparatusEditedTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector

  describe "Event" do
    @describetag :unit

    test "creates event with required id field" do
      event = %ApparatusEdited{
        id: UUID.uuid4()
      }

      assert event.id != nil
      assert event.title == nil
      assert event.slug == nil
      assert event.description == nil
    end

    test "creates event with optional fields" do
      event = %ApparatusEdited{
        id: UUID.uuid4(),
        title: "Updated Title",
        slug: "updated-slug",
        description: "Updated description"
      }

      assert event.title == "Updated Title"
      assert event.slug == "updated-slug"
      assert event.description == "Updated description"
    end

    test "requires id" do
      assert_raise ArgumentError, fn ->
        struct!(ApparatusEdited, %{})
      end
    end

    test "serializes to JSON" do
      event = %ApparatusEdited{
        id: UUID.uuid4(),
        title: "Updated Title"
      }

      json = Jason.encode!(event)
      decoded = Jason.decode!(json)
      assert decoded["title"] == "Updated Title"
    end

    test "get_changes/1 returns only non-nil fields" do
      event = %ApparatusEdited{
        id: UUID.uuid4(),
        title: "Updated Title",
        description: "Updated description"
      }

      changes = ApparatusEdited.get_changes(event)
      assert changes == %{title: "Updated Title", description: "Updated description"}
    end

    test "get_changes/1 returns empty map when only id is set" do
      event = %ApparatusEdited{
        id: UUID.uuid4()
      }

      changes = ApparatusEdited.get_changes(event)
      assert changes == %{}
    end
  end

  describe "Aggregate" do
    @describetag :unit

    test "applies ApparatusEdited to aggregate state with all fields" do
      id = UUID.uuid4()

      event = %ApparatusEdited{
        id: id,
        title: "Updated Title",
        slug: "updated-slug",
        description: "Updated description"
      }

      aggregate = %ApparatusAggregate{
        id: id,
        title: "Original Title",
        slug: "original-slug",
        description: "Original description"
      }

      result = ApparatusAggregate.apply(aggregate, event)

      assert result.id == id
      assert result.title == "Updated Title"
      assert result.slug == "updated-slug"
      assert result.description == "Updated description"
    end

    test "applies ApparatusEdited with partial update - only title changes" do
      id = UUID.uuid4()

      event = %ApparatusEdited{
        id: id,
        title: "Updated Title"
      }

      aggregate = %ApparatusAggregate{
        id: id,
        title: "Original Title",
        slug: "original-slug",
        description: "Original description"
      }

      result = ApparatusAggregate.apply(aggregate, event)

      assert result.id == id
      assert result.title == "Updated Title"
      assert result.slug == "original-slug"
      assert result.description == "Original description"
    end
  end

  describe "Projector" do
    @describetag :integration

    test "projects ApparatusEdited event to update read model" do
      id = UUID.uuid4()

      # First, catalog an apparatus
      catalog_event = %ApparatusCataloged{
        id: id,
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      catalog_metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 10,
        event_id: UUID.uuid4(),
        stream_id: "apparatus-#{id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(catalog_event, catalog_metadata)

      # Now, edit the apparatus
      edit_event = %ApparatusEdited{
        id: id,
        title: "Updated Vaulting Table"
      }

      edit_metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 11,
        event_id: UUID.uuid4(),
        stream_id: "apparatus-#{id}",
        stream_version: 2,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(edit_event, edit_metadata)

      record = Repo.get!(ApparatusReadModel, id)
      assert record.title == "Updated Vaulting Table"
      assert record.slug == "vaulting-table"
      assert record.description == "A gymnastics vault"
    end

    test "projects ApparatusEdited with all fields changed" do
      id = UUID.uuid4()

      catalog_event = %ApparatusCataloged{
        id: id,
        title: "Original",
        slug: "original-slug"
      }

      catalog_metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 20,
        event_id: UUID.uuid4(),
        stream_id: "apparatus-#{id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(catalog_event, catalog_metadata)

      edit_event = %ApparatusEdited{
        id: id,
        title: "Updated",
        slug: "updated-slug",
        description: "New description"
      }

      edit_metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 21,
        event_id: UUID.uuid4(),
        stream_id: "apparatus-#{id}",
        stream_version: 2,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(edit_event, edit_metadata)

      record = Repo.get!(ApparatusReadModel, id)
      assert record.title == "Updated"
      assert record.slug == "updated-slug"
      assert record.description == "New description"
    end
  end
end
