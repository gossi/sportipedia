defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.ArchiveApparatusTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus.Policy
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatusHandler
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusArchived
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Repo

  describe "ApparatusArchived event" do
    @describetag :unit

    test "enforces id" do
      assert_raise ArgumentError, fn ->
        struct!(ApparatusArchived, %{})
      end
    end

    test "allows optional fields to be omitted" do
      event = %ApparatusArchived{id: UUID.uuid4()}
      assert event.id != nil
    end

    test "serializes to JSON" do
      id = UUID.uuid4()
      event = %ApparatusArchived{id: id}
      json = Jason.encode!(event)
      decoded = Jason.decode!(json)

      assert decoded["id"] == id
    end
  end

  describe "ArchiveApparatus command" do
    @describetag :unit

    test "enforces id" do
      assert_raise ArgumentError, fn ->
        struct!(ArchiveApparatus, %{})
      end
    end

    test "creates command with id" do
      id = UUID.uuid4()
      cmd = %ArchiveApparatus{id: id}
      assert cmd.id == id
    end
  end

  describe "ApparatusAggregate" do
    @describetag :unit

    test "apply ApparatusArchived returns nil" do
      id = UUID.uuid4()
      event = %ApparatusArchived{id: id}
      aggregate = %ApparatusAggregate{id: id, title: "Vault", slug: "vault", description: "desc"}

      assert nil == ApparatusAggregate.apply(aggregate, event)
    end
  end

  describe "ArchiveApparatusHandler" do
    @describetag :unit

    test "creates ApparatusArchived event" do
      id = UUID.uuid4()
      cmd = %ArchiveApparatus{id: id}

      assert %ApparatusArchived{id: ^id} = ArchiveApparatusHandler.handle(nil, cmd)
    end
  end

  describe "ApparatusProjector" do
    @describetag :integration

    setup do
      id = UUID.uuid4()
      apparatus = %ApparatusReadModel{
        id: id,
        title: "Balance Beam",
        slug: "balance-beam",
        description: "A balance beam"
      }
      Repo.insert!(apparatus)
      %{apparatus: apparatus}
    end

    test "hard-deletes the read model record", %{apparatus: apparatus} do
      event = %ApparatusArchived{id: apparatus.id}

      metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "equipment/apparatus-#{event.id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(event, metadata)
      assert nil == Repo.get(ApparatusReadModel, event.id)
    end

    test "is idempotent (same event_number is skipped)", %{apparatus: apparatus} do
      event = %ApparatusArchived{id: apparatus.id}

      metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "equipment/apparatus-#{event.id}",
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

  describe "Policy" do
    @describetag :unit

    test "allows user to archive apparatus" do
      assert :ok = Policy.authorize(:archive_apparatus, %{id: UUID.uuid4()}, nil)
    end

    test "denies guest from archiving apparatus" do
      assert :error = Policy.authorize(:archive_apparatus, nil, nil)
    end
  end

  describe "Public API" do
    @describetag :integration

    setup do
      id = UUID.uuid4()
      apparatus = %ApparatusReadModel{
        id: id,
        title: "Balance Beam",
        slug: "balance-beam",
        description: "A balance beam"
      }
      Repo.insert!(apparatus)
      %{apparatus: apparatus}
    end

    test "archive_apparatus/1 succeeds", %{apparatus: apparatus} do
      assert :ok = Apparatus.archive_apparatus(apparatus.id)

      assert nil == Repo.get(ApparatusReadModel, apparatus.id)
    end

    test "archive_apparatus/1 returns {:error, :missing_id} when id is nil" do
      assert {:error, :missing_id} = Apparatus.archive_apparatus(nil)
    end

    test "archive_apparatus/1 returns {:error, :not_found} when record does not exist" do
      assert {:error, :not_found} = Apparatus.archive_apparatus(UUID.uuid4())
    end
  end
end
