defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.ArchiveApparatusTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatusHandler
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusArchived
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector

  @moduletag :integration

  describe "ArchiveApparatus command" do
    test "creates command with required id field" do
      id = UUID.uuid4()
      cmd = %ArchiveApparatus{id: id}

      assert cmd.id == id
    end

    test "requires id field" do
      assert_raise ArgumentError, fn ->
        struct!(ArchiveApparatus, %{})
      end
    end

    test "id cannot be nil" do
      cmd = %ArchiveApparatus{id: nil}

      assert_raise ArgumentError, fn ->
        Vex.validate(cmd)
      end
    end

    test "error when id does not exist" do
      id = UUID.uuid4()
      cmd = %ArchiveApparatus{id: id}

      assert {:error, [{:error, :id, :by, :not_found}]} = Vex.validate(cmd)
    end

    test "validates id must exist" do
      id = UUID.uuid4()

      ApparatusReadModel.insert_changeset(%ApparatusReadModel{}, %{
        id: id,
        title: "Vaulting Table",
        slug: "vaulting-table"
      })
      |> Repo.insert()

      cmd = %ArchiveApparatus{id: id}

      assert {:ok, _} = Vex.validate(cmd)
    end
  end

  describe "ArchiveApparatusHandler" do
    test "handles ArchiveApparatus command and returns ApparatusArchived event" do
      id = UUID.uuid4()
      cmd = %ArchiveApparatus{id: id}

      aggregate = %ApparatusAggregate{
        id: id,
        title: "Vaulting Table",
        slug: "vaulting-table"
      }

      events = ArchiveApparatusHandler.handle(aggregate, cmd)

      assert %ApparatusArchived{} = events
      assert events.id == id
    end
  end

  describe "ApparatusArchived event" do
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

  describe "ApparatusAggregate" do
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

  describe "Policy" do
    test "rejects guest users for archive_apparatus" do
      assert :error = Policy.authorize(:archive_apparatus, nil, %{})
    end

    test "allows authenticated users for archive_apparatus" do
      user = %{id: UUID.uuid4(), role: "user"}
      assert :ok = Policy.authorize(:archive_apparatus, user, %{})
    end

    test "allows admin users for archive_apparatus" do
      admin = %{id: UUID.uuid4(), role: "admin"}
      assert :ok = Policy.authorize(:archive_apparatus, admin, %{})
    end
  end

  describe "ApparatusProjector" do
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

  describe "Public API - archive_apparatus" do
    test "archives an existing apparatus successfully" do
      # First catalog an apparatus
      params = %{
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      assert {:ok, read_model} = Apparatus.catalog_apparatus(params)
      id = read_model.id

      # Now archive it
      assert :ok = Apparatus.archive_apparatus(id)

      # Verify it's gone from read model
      assert Repo.get(ApparatusReadModel, id) == nil
    end

    test "returns error for non-existent apparatus" do
      id = UUID.uuid4()

      # This should still succeed at dispatch level (event sourcing allows archiving non-existent)
      # but the read model won't exist
      assert {:error, :not_found} = Apparatus.archive_apparatus(id)
    end
  end
end
