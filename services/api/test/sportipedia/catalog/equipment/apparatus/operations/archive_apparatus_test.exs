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

  describe "Policy" do
    @describetag :unit

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

  describe "Command" do
    @describetag :unit

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

    @tag :integration
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

  describe "Handler" do
    @describetag :unit

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


  describe "Public API" do
    @describetag :integration

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
