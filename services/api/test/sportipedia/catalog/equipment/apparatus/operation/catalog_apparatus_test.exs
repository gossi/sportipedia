defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.CatalogApparatusTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Repo
  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatusHandler

  describe "Internal API" do
    test "returns nil when no apparatus exists" do
      assert nil == ApparatusInternal.apparatus_by_slug("non-existent")
    end
  end

  describe "Validator" do
    test "allows unique slug" do
      assert :ok =
               Sportipedia.Catalog.Equipment.Apparatus.Validators.UniqueSlug.validate(
                 "unique-slug",
                 nil
               )
    end
  end

  describe "Projector" do
    test "projects apparatus cataloged event into read model" do
      event = %ApparatusCataloged{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

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

      record = Repo.get!(ApparatusReadModel, event.id)
      assert record.title == "Vaulting Table"
      assert record.slug == "vaulting-table"
      assert record.description == "A gymnastics vault"
    end

    test "is idempotent when same event is projected twice" do
      event = %ApparatusCataloged{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: nil
      }

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

      assert [record] = Repo.all(ApparatusReadModel)
      assert record.id == event.id
    end

    test "catches unique constraint violation on slug" do
      existing = %ApparatusCataloged{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: nil
      }

      metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "equipment/apparatus-#{existing.id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(existing, metadata)

      duplicate = %ApparatusCataloged{
        id: UUID.uuid4(),
        title: "Another Vault",
        slug: "vaulting-table",
        description: nil
      }

      duplicate_metadata = %{
        metadata
        | handler_name: "equipment.apparatus_projection",
          event_number: 2,
          event_id: UUID.uuid4(),
          stream_id: "equipment/apparatus-#{duplicate.id}",
          stream_version: 1
      }

      assert {:error, _} = ApparatusProjector.handle(duplicate, duplicate_metadata)
    end
  end

  describe "Handler" do
    @tag :unit
    test "returns apparatus cataloged event from command" do
      command = CatalogApparatus.new(%{title: "Vault", slug: "vault", description: "A vault"})

      assert %ApparatusCataloged{title: "Vault", slug: "vault", description: "A vault"} =
               CatalogApparatusHandler.handle(%ApparatusAggregate{}, command)
    end

    @tag :unit
    test "generates a UUID for the apparatus id" do
      command = CatalogApparatus.new(%{title: "Vault", slug: "vault"})

      assert %ApparatusCataloged{id: id} = CatalogApparatusHandler.handle(%ApparatusAggregate{}, command)
      assert String.length(id) == 36
    end
  end

  describe "Command" do
    @tag :unit
    test "creates command struct with valid attrs" do
      command = CatalogApparatus.new(%{title: "Vault", slug: "vault"})

      assert command.title == "Vault"
      assert command.slug == "vault"
      assert command.description == nil
    end

    @tag :unit
    test "creates command with optional description" do
      command = CatalogApparatus.new(%{title: "Vault", slug: "vault", description: "A vault"})

      assert command.description == "A vault"
    end

    @tag :unit
    test "enforces required fields on command" do
      assert_raise ArgumentError, fn ->
        struct!(CatalogApparatus, %{})
      end
    end

    @tag :unit
    test "validates presence of title" do
      {:error, errors} =
        CatalogApparatus.new(%{slug: "vault"})
        |> Vex.validate()

      assert errors == [{:error, :title, :presence, "must be present"}]
    end

    @tag :unit
    test "validates presence of slug" do
      {:error, errors} =
        CatalogApparatus.new(%{title: "Vault"})
        |> Vex.validate()

      assert errors == [{:error, :slug, :presence, "must be present"}]
    end
  end

  describe "Policy" do
    @tag :unit
    test "allows user to catalog apparatus" do
      assert :ok = Policy.authorize(:catalog_apparatus, %{role: "user"}, %{})
    end

    @tag :unit
    test "denies guest to catalog apparatus" do
      assert :error = Policy.authorize(:catalog_apparatus, nil, %{})
    end
  end

  describe "Aggregate" do
    @tag :unit
    test "applies apparatus cataloged event to aggregate state" do
      event = %ApparatusCataloged{
        id: "123",
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      aggregate = ApparatusAggregate.apply(%ApparatusAggregate{}, event)

      assert aggregate.id == "123"
      assert aggregate.title == "Vaulting Table"
      assert aggregate.slug == "vaulting-table"
      assert aggregate.description == "A gymnastics vault"
    end
  end

  describe "Event" do
    @tag :unit
    test "creates event struct with required fields" do
      event = %ApparatusCataloged{id: "123", title: "Vault", slug: "vault"}

      assert event.id == "123"
      assert event.title == "Vault"
      assert event.slug == "vault"
      assert event.description == nil
    end

    @tag :unit
    test "creates event struct with optional description" do
      event = %ApparatusCataloged{id: "123", title: "Vault", slug: "vault", description: "A vault"}

      assert event.description == "A vault"
    end

    @tag :unit
    test "enforces required fields on event" do
      assert_raise ArgumentError, fn ->
        struct!(ApparatusCataloged, %{})
      end
    end

    @tag :unit
    test "serializes event to JSON" do
      event = %ApparatusCataloged{id: "123", title: "Vaulting Table", slug: "vaulting-table"}

      json = Jason.encode!(event)

      assert json =~ ~s("id":"123")
      assert json =~ ~s("title":"Vaulting Table")
      assert json =~ ~s("slug":"vaulting-table")
    end
  end

  describe "Public API" do
    test "returns validation failure when title is missing" do
      assert {:error, {:validation_failure, %{title: ["must be present"]}}} =
               Apparatus.catalog_apparatus(%{slug: "vaulting-table"})
    end

    test "returns validation failure when slug is missing" do
      assert {:error, {:validation_failure, %{slug: ["must be present"]}}} =
               Apparatus.catalog_apparatus(%{title: "Vaulting Table"})
    end

    test "returns validation failure when slug already exists" do
      # Manually project an apparatus to simulate existing slug
      event = %ApparatusCataloged{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: nil
      }

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

      assert {:error, {:validation_failure, %{slug: ["slug already exists"]}}} =
               Apparatus.catalog_apparatus(%{
                 title: "Another Vaulting Table",
                 slug: "vaulting-table"
               })
    end

    test "rejects duplicate slug with different casing" do
      event = %ApparatusCataloged{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "my-slug",
        description: nil
      }

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

      assert {:error, {:validation_failure, %{slug: ["slug already exists"]}}} =
               Apparatus.catalog_apparatus(%{
                 title: "Another Vaulting Table",
                 slug: "My-Slug"
               })
    end
  end
end
