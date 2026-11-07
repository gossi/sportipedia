defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.ApparatusCatalogedTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector

  describe "Event" do
    @describetag :unit

    test "creates event with required fields" do
      event = %ApparatusCataloged{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "vaulting-table"
      }

      assert event.title == "Vaulting Table"
      assert event.slug == "vaulting-table"
    end

    test "creates event with optional description" do
      event = %ApparatusCataloged{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      assert event.description == "A gymnastics vault"
    end

    test "requires id, title, and slug" do
      assert_raise ArgumentError, fn ->
        struct!(ApparatusCataloged, %{})
      end
    end

    test "serializes to JSON" do
      event = %ApparatusCataloged{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      json = Jason.encode!(event)
      assert Jason.decode!(json)["title"] == "Vaulting Table"
    end
  end

  describe "Aggregate" do
    @describetag :unit

    test "applies ApparatusCataloged to aggregate state" do
      event = %ApparatusCataloged{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      result = ApparatusAggregate.apply(%ApparatusAggregate{}, event)

      assert result.id == event.id
      assert result.title == "Vaulting Table"
      assert result.slug == "vaulting-table"
      assert result.description == "A gymnastics vault"
    end
  end

  describe "Projector" do
    @describetag :integration

    test "projects ApparatusCataloged event to read model" do
      id = UUID.uuid4()

      event = %ApparatusCataloged{
        id: id,
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 1,
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

      record = Repo.get!(ApparatusReadModel, id)
      assert record.title == "Vaulting Table"
      assert record.slug == "vaulting-table"
      assert record.description == "A gymnastics vault"
    end

    test "is idempotent - same event_number is skipped" do
      id = UUID.uuid4()

      event = %ApparatusCataloged{
        id: id,
        title: "Balance Beam",
        slug: "balance-beam"
      }

      metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 2,
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
      assert :ok = ApparatusProjector.handle(event, metadata)

      assert [record] = Repo.all(ApparatusReadModel)
      assert record.id == id
    end
  end
end
