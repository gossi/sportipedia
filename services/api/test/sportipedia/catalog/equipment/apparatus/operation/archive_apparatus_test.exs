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
  alias Sportipedia.Catalog.Repo

  @moduletag :integration

  describe "ArchiveApparatus command" do
    test "creates struct with enforced id field" do
      id = UUID.uuid4()
      cmd = %ArchiveApparatus{id: id}
      assert cmd.id == id
    end

    test "raises ArgumentError when id is missing" do
      assert_raise ArgumentError, fn ->
        struct!(ArchiveApparatus, %{})
      end
    end
  end

  describe "Policy" do
    @describetag :unit

    test "denies guest from archiving apparatus" do
      assert :error = Policy.authorize(:archive_apparatus, nil, %{})
    end

    test "allows user to archive apparatus" do
      user = %Sportipedia.Auth.User{id: UUID.uuid4(), role: "user"}
      assert :ok = Policy.authorize(:archive_apparatus, user, %{})
    end

    test "allows admin to archive apparatus" do
      admin = %Sportipedia.Auth.User{id: UUID.uuid4(), role: "admin"}
      assert :ok = Policy.authorize(:archive_apparatus, admin, %{})
    end
  end

  describe "ApparatusAggregate" do
    @describetag :unit

    test "applies ApparatusArchived to aggregate state returning nil" do
      id = UUID.uuid4()

      aggregate = %ApparatusAggregate{
        id: id,
        title: "Balance Beam",
        slug: "balance-beam",
        description: nil
      }

      event = %ApparatusArchived{id: id}
      assert nil == ApparatusAggregate.apply(aggregate, event)
    end
  end

  describe "ArchiveApparatusHandler" do
    @describetag :unit

    test "returns ApparatusArchived event when aggregate exists" do
      id = UUID.uuid4()

      aggregate = %ApparatusAggregate{
        id: id,
        title: "Balance Beam",
        slug: "balance-beam",
        description: nil
      }

      cmd = %ArchiveApparatus{id: id}
      events = ArchiveApparatusHandler.handle(aggregate, cmd)

      assert [%ApparatusArchived{id: ^id}] = events
    end

    test "returns error when aggregate does not exist" do
      aggregate = %ApparatusAggregate{}
      cmd = %ArchiveApparatus{id: UUID.uuid4()}

      assert {:error, :apparatus_not_found} = ArchiveApparatusHandler.handle(aggregate, cmd)
    end
  end

  describe "ApparatusProjector" do
    test "hard-deletes read model on ApparatusArchived" do
      id = UUID.uuid4()

      # Insert a read model record (simulate cataloged apparatus)
      %ApparatusReadModel{}
      |> ApparatusReadModel.insert_changeset(%{
        id: id,
        title: "Balance Beam",
        slug: "balance-beam",
        description: nil
      })
      |> Repo.insert!()

      assert Repo.get(ApparatusReadModel, id) != nil

      # Project the archive event
      event = %ApparatusArchived{id: id}

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

      # Verify the record is deleted
      assert Repo.get(ApparatusReadModel, id) == nil
    end

    test "is idempotent when read model already deleted" do
      id = UUID.uuid4()

      event = %ApparatusArchived{id: id}

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
    end
  end

  describe "Apparatus.archive_apparatus/1" do
    test "archives an existing apparatus and returns it" do
      # First, catalog an apparatus
      {:ok, apparatus} =
        Apparatus.catalog_apparatus(%{
          title: "Balance Beam",
          slug: "balance-beam",
          description: nil
        })

      id = apparatus.id

      # Verify it exists
      assert Repo.get(ApparatusReadModel, id) != nil

      # Archive it
      assert {:ok, archived_apparatus} = Apparatus.archive_apparatus(id)
      assert archived_apparatus.id == id
      assert archived_apparatus.title == "Balance Beam"

      # Verify the read model is deleted
      assert Repo.get(ApparatusReadModel, id) == nil
    end

    test "returns error when archiving non-existent apparatus" do
      id = UUID.uuid4()
      assert {:error, :notfound} = Apparatus.archive_apparatus(id)
    end
  end

  describe "ApparatusArchived event" do
    test "creates struct with enforced id field" do
      id = UUID.uuid4()
      event = %ApparatusArchived{id: id}
      assert event.id == id
    end

    test "raises ArgumentError when id is missing" do
      assert_raise ArgumentError, fn ->
        struct!(ApparatusArchived, %{})
      end
    end

    test "serializes to JSON" do
      id = UUID.uuid4()
      event = %ApparatusArchived{id: id}
      json = Jason.encode!(event)
      decoded = Jason.decode!(json)
      assert decoded["id"] == id
    end
  end
end
