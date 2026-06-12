defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.CatalogApparatusTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatusHandler
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector

  @moduletag :integration

  describe "CatalogApparatus command" do
    test "creates command with required fields" do
      cmd = %CatalogApparatus{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "vaulting-table"
      }

      assert cmd.title == "Vaulting Table"
      assert cmd.slug == "vaulting-table"
    end

    test "creates command with optional description" do
      cmd = %CatalogApparatus{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      assert cmd.description == "A gymnastics vault"
    end

    test "requires id, title, and slug" do
      assert_raise ArgumentError, fn ->
        struct!(CatalogApparatus, %{})
      end
    end

    test "validates presence of title" do
      cmd = %CatalogApparatus{
        id: UUID.uuid4(),
        title: nil,
        slug: "vaulting-table"
      }

      assert {:error, _errors} = Vex.validate(cmd)
    end

    test "validates presence of slug" do
      cmd = %CatalogApparatus{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: nil
      }

      assert {:error, _errors} = Vex.validate(cmd)
    end
  end

  describe "CatalogApparatusHandler" do
    test "handles CatalogApparatus command and returns ApparatusCataloged event" do
      id = UUID.uuid4()

      cmd = %CatalogApparatus{
        id: id,
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      aggregate = %ApparatusAggregate{}

      events = CatalogApparatusHandler.handle(aggregate, cmd)

      assert %ApparatusCataloged{} = events
      assert events.id == id
      assert events.title == "Vaulting Table"
      assert events.slug == "vaulting-table"
      assert events.description == "A gymnastics vault"
    end
  end

  describe "Public API - catalog_apparatus" do
    test "catalogs an apparatus successfully" do
      params = %{
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      assert {:ok, read_model} = Apparatus.catalog_apparatus(params)

      assert read_model.title == "Vaulting Table"
      assert read_model.slug == "vaulting-table"
      assert read_model.description == "A gymnastics vault"
      assert read_model.id != nil
    end

    test "catalogs an apparatus without description" do
      params = %{
        title: "Pommel Horse",
        slug: "pommel-horse"
      }

      assert {:ok, read_model} = Apparatus.catalog_apparatus(params)

      assert read_model.title == "Pommel Horse"
      assert read_model.slug == "pommel-horse"
      assert read_model.description == nil
    end

    test "returns validation error for missing title" do
      params = %{slug: "vaulting-table"}

      assert {:error, {:validation_failure, _errors}} = Apparatus.catalog_apparatus(params)
    end

    test "returns validation error for missing slug" do
      params = %{title: "Vaulting Table"}

      assert {:error, {:validation_failure, _errors}} = Apparatus.catalog_apparatus(params)
    end

    test "returns validation error for duplicate slug" do
      params = %{title: "Vaulting Table", slug: "vaulting-table"}

      assert {:ok, _} = Apparatus.catalog_apparatus(params)
      assert {:error, {:validation_failure, _errors}} = Apparatus.catalog_apparatus(params)
    end
  end

  describe "Policy" do
    test "rejects guest users" do
      assert :error = Policy.authorize(:catalog_apparatus, nil, %{})
    end

    test "allows authenticated users" do
      user = %{id: UUID.uuid4(), role: "user"}
      assert :ok = Policy.authorize(:catalog_apparatus, user, %{})
    end

    test "allows admin users" do
      admin = %{id: UUID.uuid4(), role: "admin"}
      assert :ok = Policy.authorize(:catalog_apparatus, admin, %{})
    end
  end

  describe "ApparatusProjector" do
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

  describe "ApparatusAggregate" do
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

  describe "ApparatusCataloged event" do
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
end
