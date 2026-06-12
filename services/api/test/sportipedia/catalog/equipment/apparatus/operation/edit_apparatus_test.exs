defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.EditApparatusTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatusHandler
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector

  @moduletag :integration

  describe "ApparatusEdited event" do
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

  describe "EditApparatus command" do
    test "creates command with required id field" do
      cmd = %EditApparatus{
        id: UUID.uuid4()
      }

      assert cmd.id != nil
      assert cmd.title == nil
      assert cmd.slug == nil
      assert cmd.description == nil
    end

    test "creates command with optional fields" do
      cmd = %EditApparatus{
        id: UUID.uuid4(),
        title: "Updated Title",
        slug: "updated-slug",
        description: "Updated description"
      }

      assert cmd.title == "Updated Title"
      assert cmd.slug == "updated-slug"
      assert cmd.description == "Updated description"
    end

    test "requires id" do
      assert_raise ArgumentError, fn ->
        struct!(EditApparatus, %{})
      end
    end

    test "does not have Vex slug validation (uniqueness checked in handler)" do
      # Slug uniqueness is now checked in the handler, not via Vex
      cmd = %EditApparatus{
        id: UUID.uuid4(),
        slug: "any-slug"
      }

      assert {:ok, _} = Vex.validate(cmd)
    end

    test "does not validate slug when slug is nil" do
      cmd = %EditApparatus{
        id: UUID.uuid4(),
        slug: nil
      }

      assert {:ok, _} = Vex.validate(cmd)
    end
  end

  describe "EditApparatusHandler" do
    test "handles EditApparatus command and returns ApparatusEdited event" do
      id = UUID.uuid4()

      cmd = %EditApparatus{
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

      events = EditApparatusHandler.handle(aggregate, cmd)

      assert %ApparatusEdited{} = events
      assert events.id == id
      assert events.title == "Updated Title"
      assert events.slug == "updated-slug"
      assert events.description == "Updated description"
    end

    test "handles partial update with only title" do
      id = UUID.uuid4()

      cmd = %EditApparatus{
        id: id,
        title: "Updated Title"
      }

      aggregate = %ApparatusAggregate{
        id: id,
        title: "Original Title",
        slug: "original-slug",
        description: "Original description"
      }

      events = EditApparatusHandler.handle(aggregate, cmd)

      assert %ApparatusEdited{} = events
      assert events.id == id
      assert events.title == "Updated Title"
      assert events.slug == nil
      assert events.description == nil
    end

    test "allows keeping the same slug" do
      id = UUID.uuid4()

      cmd = %EditApparatus{
        id: id,
        title: "Updated Title",
        slug: "original-slug"
      }

      aggregate = %ApparatusAggregate{
        id: id,
        title: "Original Title",
        slug: "original-slug",
        description: "Original description"
      }

      result = EditApparatusHandler.handle(aggregate, cmd)

      assert %ApparatusEdited{} = result
      assert result.slug == "original-slug"
    end

    test "rejects changing to a slug that already exists" do
      # First, catalog an apparatus with a known slug
      params = %{title: "Other Apparatus", slug: "taken-slug"}
      assert {:ok, _} = Apparatus.catalog_apparatus(params)

      id = UUID.uuid4()

      cmd = %EditApparatus{
        id: id,
        slug: "taken-slug"
      }

      aggregate = %ApparatusAggregate{
        id: id,
        title: "My Apparatus",
        slug: "my-slug",
        description: nil
      }

      result = EditApparatusHandler.handle(aggregate, cmd)

      assert {:error, {:validation_failure, %{slug: ["slug already exists"]}}} = result
    end
  end

  describe "ApparatusAggregate" do
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

  describe "ApparatusProjector - ApparatusEdited" do
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

  describe "Policy - edit_apparatus" do
    test "rejects guest users" do
      assert :error = Policy.authorize(:edit_apparatus, nil, %{})
    end

    test "allows authenticated users" do
      user = %{id: UUID.uuid4(), role: "user"}
      assert :ok = Policy.authorize(:edit_apparatus, user, %{})
    end

    test "allows admin users" do
      admin = %{id: UUID.uuid4(), role: "admin"}
      assert :ok = Policy.authorize(:edit_apparatus, admin, %{})
    end
  end

  describe "Public API - edit_apparatus" do
    test "edits an apparatus title successfully" do
      # First catalog an apparatus
      params = %{
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      assert {:ok, created} = Apparatus.catalog_apparatus(params)

      # Edit only the title
      edit_params = %{id: created.id, title: "Updated Vaulting Table"}
      assert {:ok, updated} = Apparatus.edit_apparatus(edit_params)

      assert updated.title == "Updated Vaulting Table"
      assert updated.slug == "vaulting-table"
      assert updated.description == "A gymnastics vault"
    end

    test "edits an apparatus slug successfully" do
      params = %{title: "Pommel Horse", slug: "pommel-horse"}
      assert {:ok, created} = Apparatus.catalog_apparatus(params)

      edit_params = %{id: created.id, slug: "pommel-horse-updated"}
      assert {:ok, updated} = Apparatus.edit_apparatus(edit_params)

      assert updated.title == "Pommel Horse"
      assert updated.slug == "pommel-horse-updated"
    end

    test "edits an apparatus description successfully" do
      params = %{title: "Balance Beam", slug: "balance-beam"}
      assert {:ok, created} = Apparatus.catalog_apparatus(params)

      edit_params = %{id: created.id, description: "A narrow beam"}
      assert {:ok, updated} = Apparatus.edit_apparatus(edit_params)

      assert updated.title == "Balance Beam"
      assert updated.slug == "balance-beam"
      assert updated.description == "A narrow beam"
    end

    test "edits all fields at once" do
      params = %{title: "Rings", slug: "rings"}
      assert {:ok, created} = Apparatus.catalog_apparatus(params)

      edit_params = %{
        id: created.id,
        title: "Still Rings",
        slug: "still-rings",
        description: "Hanging rings"
      }

      assert {:ok, updated} = Apparatus.edit_apparatus(edit_params)

      assert updated.title == "Still Rings"
      assert updated.slug == "still-rings"
      assert updated.description == "Hanging rings"
    end

    test "succeeds when editing an apparatus keeping the same slug" do
      params = %{title: "Vaulting Table", slug: "vaulting-table"}
      assert {:ok, created} = Apparatus.catalog_apparatus(params)

      # Edit title but keep the same slug — should succeed
      edit_params = %{id: created.id, title: "Updated Vaulting Table", slug: "vaulting-table"}
      assert {:ok, updated} = Apparatus.edit_apparatus(edit_params)

      assert updated.title == "Updated Vaulting Table"
      assert updated.slug == "vaulting-table"
    end

    test "succeeds when called with string-keyed params" do
      params = %{title: "Vaulting Table", slug: "vaulting-table"}
      assert {:ok, created} = Apparatus.catalog_apparatus(params)

      # Simulate controller passing string-keyed params
      edit_params = %{"id" => created.id, "title" => "Updated Vault"}
      assert {:ok, updated} = Apparatus.edit_apparatus(edit_params)

      assert updated.title == "Updated Vault"
      assert updated.slug == "vaulting-table"
    end

    test "returns validation error for duplicate slug" do
      params1 = %{title: "Apparatus A", slug: "apparatus-a"}
      assert {:ok, _} = Apparatus.catalog_apparatus(params1)

      params2 = %{title: "Apparatus B", slug: "apparatus-b"}
      assert {:ok, created} = Apparatus.catalog_apparatus(params2)

      # Try to edit apparatus B to use apparatus A's slug
      edit_params = %{id: created.id, slug: "apparatus-a"}
      assert {:error, {:validation_failure, _errors}} = Apparatus.edit_apparatus(edit_params)
    end
  end
end
