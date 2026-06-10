defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.EditApparatusTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatusHandler
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector
  alias Sportipedia.Catalog.Repo

  describe "Public API" do
    @describetag :integration

    test "edit_apparatus/1 updates an existing apparatus (partial update)" do
      {:ok, apparatus} =
        Apparatus.catalog_apparatus(%{
          title: "Vaulting Table",
          slug: "vaulting-table",
          description: "A gymnastics vault"
        })

      assert {:ok, updated} =
               Apparatus.edit_apparatus(%{id: apparatus.id, title: "Updated Vaulting Table"})

      assert updated.id == apparatus.id
      assert updated.title == "Updated Vaulting Table"
      assert updated.slug == "vaulting-table"
      assert updated.description == "A gymnastics vault"
    end

    test "edit_apparatus/1 updates slug" do
      {:ok, apparatus} =
        Apparatus.catalog_apparatus(%{title: "Vaulting Table", slug: "vaulting-table"})

      assert {:ok, updated} =
               Apparatus.edit_apparatus(%{id: apparatus.id, slug: "new-vaulting-table"})

      assert updated.slug == "new-vaulting-table"
      assert updated.title == "Vaulting Table"
    end

    test "edit_apparatus/1 returns validation error for empty title" do
      {:ok, apparatus} =
        Apparatus.catalog_apparatus(%{title: "Vaulting Table", slug: "vaulting-table"})

      assert {:error, {:validation_failure, %{title: _}}} =
               Apparatus.edit_apparatus(%{id: apparatus.id, title: ""})
    end

    test "edit_apparatus/1 returns validation error for duplicate slug" do
      {:ok, apparatus1} =
        Apparatus.catalog_apparatus(%{title: "Apparatus 1", slug: "apparatus-1"})

      {:ok, _apparatus2} =
        Apparatus.catalog_apparatus(%{title: "Apparatus 2", slug: "apparatus-2"})

      assert {:error, {:validation_failure, %{slug: _}}} =
               Apparatus.edit_apparatus(%{id: apparatus1.id, slug: "apparatus-2"})
    end

    test "edit_apparatus/1 allows keeping the same slug" do
      {:ok, apparatus} =
        Apparatus.catalog_apparatus(%{title: "Vaulting Table", slug: "vaulting-table"})

      assert {:ok, updated} =
               Apparatus.edit_apparatus(%{
                 id: apparatus.id,
                 title: "Updated Title",
                 slug: "vaulting-table"
               })

      assert updated.title == "Updated Title"
      assert updated.slug == "vaulting-table"
    end
  end

  describe "Policy" do
    @describetag :unit

    test "allows authenticated user to edit an apparatus" do
      assert Policy.authorize(:edit_apparatus, %{id: "user-123"}, %{}) == :ok
    end

    test "rejects unauthenticated user" do
      assert Policy.authorize(:edit_apparatus, nil, %{}) == :error
    end
  end

  describe "Projector" do
    @describetag :integration

    test "projects ApparatusEdited event to update read model (partial update)" do
      apparatus_id = UUID.uuid4()

      %ApparatusReadModel{}
      |> ApparatusReadModel.insert_changeset(%{
        id: apparatus_id,
        title: "Old Title",
        slug: "old-slug",
        description: "Old description"
      })
      |> Repo.insert!()

      event = %ApparatusEdited{
        id: apparatus_id,
        title: "Updated Title",
        slug: nil,
        description: nil
      }

      metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 2,
        event_id: UUID.uuid4(),
        stream_id: "apparatus-#{event.id}",
        stream_version: 2,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(event, metadata)

      apparatus = Repo.get!(ApparatusReadModel, apparatus_id)
      assert apparatus.title == "Updated Title"
      assert apparatus.slug == "old-slug"
      assert apparatus.description == "Old description"
    end

    test "projects ApparatusEdited event with all fields changed" do
      apparatus_id = UUID.uuid4()

      %ApparatusReadModel{}
      |> ApparatusReadModel.insert_changeset(%{
        id: apparatus_id,
        title: "Old Title",
        slug: "old-slug",
        description: "Old description"
      })
      |> Repo.insert!()

      event = %ApparatusEdited{
        id: apparatus_id,
        title: "New Title",
        slug: "new-slug",
        description: "New description"
      }

      metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 3,
        event_id: UUID.uuid4(),
        stream_id: "apparatus-#{event.id}",
        stream_version: 2,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(event, metadata)

      apparatus = Repo.get!(ApparatusReadModel, apparatus_id)
      assert apparatus.title == "New Title"
      assert apparatus.slug == "new-slug"
      assert apparatus.description == "New description"
    end

    test "is no-op when apparatus does not exist" do
      event = %ApparatusEdited{
        id: UUID.uuid4(),
        title: "Updated Title"
      }

      metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 4,
        event_id: UUID.uuid4(),
        stream_id: "apparatus-#{event.id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(event, metadata)
      assert [] == Repo.all(ApparatusReadModel)
    end
  end

  describe "Read Model" do
    @describetag :unit

    test "update_changeset/2 updates only provided fields" do
      read_model = %ApparatusReadModel{
        id: "rm-1",
        title: "Old Title",
        slug: "old-slug",
        description: "Old description"
      }

      changeset = ApparatusReadModel.update_changeset(read_model, %{title: "New Title"})

      assert changeset.changes == %{title: "New Title"}
      assert changeset.data.title == "Old Title"
      assert changeset.data.slug == "old-slug"
    end

    test "update_changeset/2 updates multiple fields" do
      read_model = %ApparatusReadModel{
        id: "rm-1",
        title: "Old Title",
        slug: "old-slug",
        description: "Old description"
      }

      changeset =
        ApparatusReadModel.update_changeset(read_model, %{
          title: "New Title",
          slug: "new-slug"
        })

      assert changeset.changes == %{title: "New Title", slug: "new-slug"}
    end
  end

  describe "Aggregate" do
    @describetag :unit

    test "applies ApparatusEdited event with all fields to aggregate state" do
      event = %ApparatusEdited{
        id: "agg-1",
        title: "Updated Title",
        slug: "updated-slug",
        description: "Updated description"
      }

      aggregate = %ApparatusAggregate{
        id: "agg-1",
        title: "Old Title",
        slug: "old-slug",
        description: "Old description"
      }

      result = ApparatusAggregate.apply(aggregate, event)

      assert result.id == "agg-1"
      assert result.title == "Updated Title"
      assert result.slug == "updated-slug"
      assert result.description == "Updated description"
    end

    test "applies ApparatusEdited event with partial fields (only updates provided fields)" do
      event = %ApparatusEdited{
        id: "agg-1",
        title: "Updated Title",
        slug: nil,
        description: nil
      }

      aggregate = %ApparatusAggregate{
        id: "agg-1",
        title: "Old Title",
        slug: "old-slug",
        description: "Old description"
      }

      result = ApparatusAggregate.apply(aggregate, event)

      assert result.id == "agg-1"
      assert result.title == "Updated Title"
      assert result.slug == "old-slug"
      assert result.description == "Old description"
    end
  end

  describe "Command Handler" do
    @describetag :unit

    test "creates ApparatusEdited event from EditApparatus command with all fields" do
      cmd =
        EditApparatus.new(
          id: "cmd-1",
          title: "Updated Title",
          slug: "updated-slug",
          description: "Updated description"
        )

      aggregate = %ApparatusAggregate{id: "cmd-1", title: "Old", slug: "old", description: "old"}

      assert %ApparatusEdited{
               id: "cmd-1",
               title: "Updated Title",
               slug: "updated-slug",
               description: "Updated description"
             } = EditApparatusHandler.handle(aggregate, cmd)
    end

    test "creates ApparatusEdited event with only changed fields (partial update)" do
      cmd = EditApparatus.new(id: "cmd-1", title: "Updated Title")

      aggregate = %ApparatusAggregate{id: "cmd-1", title: "Old", slug: "old-slug"}

      event = EditApparatusHandler.handle(aggregate, cmd)

      assert event.id == "cmd-1"
      assert event.title == "Updated Title"
      assert event.slug == nil
      assert event.description == nil
    end

    test "returns error when aggregate does not exist" do
      cmd = EditApparatus.new(id: "non-existent", title: "Updated")

      aggregate = %ApparatusAggregate{}

      assert {:error, :apparatus_not_found} = EditApparatusHandler.handle(aggregate, cmd)
    end
  end

  describe "Command" do
    @describetag :unit

    test "struct has enforced id field" do
      assert_raise ArgumentError, ~r"keys must also be given", fn ->
        struct!(EditApparatus, %{})
      end
    end

    test "can be created with only id (partial update)" do
      cmd = %EditApparatus{id: "cmd-1"}

      assert cmd.id == "cmd-1"
      assert cmd.title == nil
      assert cmd.slug == nil
      assert cmd.description == nil
    end

    test "is valid with only id" do
      cmd = EditApparatus.new(id: UUID.uuid4())

      assert Vex.valid?(cmd)
    end

    test "is valid with title" do
      cmd = EditApparatus.new(id: UUID.uuid4(), title: "Updated Title")

      assert Vex.valid?(cmd)
    end

    test "is invalid with empty title" do
      cmd = EditApparatus.new(id: UUID.uuid4(), title: "")

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :title, _, _}, &1))
    end

    test "is invalid with empty slug" do
      cmd = EditApparatus.new(id: UUID.uuid4(), slug: "")

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :slug, _, _}, &1))
    end

    @tag :integration
    test "is invalid with duplicate slug (different apparatus)" do
      slug = "vaulting-table"

      %ApparatusReadModel{}
      |> ApparatusReadModel.insert_changeset(%{
        id: UUID.uuid4(),
        title: "Existing",
        slug: slug
      })
      |> Repo.insert!()

      cmd = EditApparatus.new(id: UUID.uuid4(), slug: slug)

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :slug, _, "slug already exists"}, &1))
    end

    @tag :integration
    test "is valid when slug is unchanged (self-exclusion)" do
      apparatus_id = UUID.uuid4()
      slug = "vaulting-table"

      %ApparatusReadModel{}
      |> ApparatusReadModel.insert_changeset(%{
        id: apparatus_id,
        title: "Vaulting Table",
        slug: slug
      })
      |> Repo.insert!()

      cmd = EditApparatus.new(id: apparatus_id, slug: slug)

      assert Vex.valid?(cmd)
    end
  end

  describe "Event" do
    @describetag :unit

    test "struct has enforced id field" do
      assert_raise ArgumentError, ~r"keys must also be given", fn ->
        struct!(ApparatusEdited, %{})
      end
    end

    test "can be created with only id (partial update)" do
      event = %ApparatusEdited{id: "e-1"}

      assert event.id == "e-1"
      assert event.title == nil
      assert event.slug == nil
      assert event.description == nil
    end

    test "can be encoded to JSON" do
      event = %ApparatusEdited{
        id: "e-1",
        title: "Updated Title",
        slug: "updated-slug"
      }

      encoded = Jason.encode!(event)

      assert encoded =~ ~s("id":"e-1")
      assert encoded =~ ~s("title":"Updated Title")
      assert encoded =~ ~s("slug":"updated-slug")
    end

    test "get_changes/1 returns only non-nil fields" do
      event = %ApparatusEdited{
        id: "e-1",
        title: "Updated Title",
        slug: nil,
        description: "New description"
      }

      changes = ApparatusEdited.get_changes(event)

      assert changes == %{id: "e-1", title: "Updated Title", description: "New description"}
      refute Map.has_key?(changes, :slug)
    end

    test "get_changes/1 returns only id when all other fields are nil" do
      event = %ApparatusEdited{id: "e-1"}

      changes = ApparatusEdited.get_changes(event)

      assert changes == %{id: "e-1"}
    end
  end
end
