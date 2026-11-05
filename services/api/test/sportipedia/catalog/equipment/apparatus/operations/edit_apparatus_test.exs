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

  describe "Policy" do
    @describetag :unit

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

  describe "Command" do
    @describetag :unit

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

    test "id cannot be nil" do
      cmd = %EditApparatus{id: nil}

      assert_raise ArgumentError, fn ->
        Vex.validate(cmd)
      end
    end

    test "error when id does not exist" do
      id = UUID.uuid4()
      cmd = %EditApparatus{id: id}

      assert {:error, [{:error, :id, :by, :not_found}]} = Vex.validate(cmd)
    end

    @tag :integration
    test "validates id must exist" do
      id = UUID.uuid4()

      new_apparatus(%{
        id: id,
        title: "Vaulting Table",
        slug: "vaulting-table"
      })

      cmd = %EditApparatus{id: id}

      assert {:ok, _} = Vex.validate(cmd)
    end

    @tag :integration
    test "change title, but keep slug" do
      id = UUID.uuid4()

      new_apparatus(%{
        id: id,
        title: "Vaulting Table",
        slug: "vaulting-table"
      })

      cmd = %EditApparatus{
        id: id,
        title: "Vaulting",
        slug: "vaulting-table"
      }

      assert {:ok, _} = Vex.validate(cmd)
    end

    @tag :integration
    test "check slug for uniqueness" do
      id = UUID.uuid4()

      new_apparatus(%{
        id: id,
        title: "Vaulting Table",
        slug: "vaulting-table"
      })

      cmd = %EditApparatus{
        id: id,
        slug: "any-slug"
      }

      assert {:ok, _} = Vex.validate(cmd)
    end

    @tag :integration
    test "rejects when slug is not unique" do
      id = UUID.uuid4()

      new_apparatuses([
        %{
          id: UUID.uuid4(),
          title: "Beam",
          slug: "beam"
        },
        %{
          id: id,
          title: "Vaulting Table",
          slug: "vaulting-table"
        }
      ])

      cmd = %EditApparatus{
        id: id,
        slug: "beam"
      }

      assert {:error, [{:error, :slug, :by, :slug_exists}]} =
               Vex.validate(cmd)
    end

    @tag :integration
    test "does not validate slug when slug is nil" do
      id = UUID.uuid4()

      new_apparatus(%{
        id: id,
        title: "Vaulting Table",
        slug: "vaulting-table"
      })

      cmd = %EditApparatus{
        id: id,
        slug: nil
      }

      assert {:ok, _} = Vex.validate(cmd)
    end
  end

  describe "Handler" do
    @describetag :unit

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

      events = EditApparatusHandler.handle(%ApparatusAggregate{}, cmd)

      assert %ApparatusEdited{} = events
      assert events.id == id
      assert events.title == "Updated Title"
      assert events.slug == nil
      assert events.description == nil
    end
  end

  describe "Public API" do
    @describetag :integration

    test "edits an apparatus title successfully" do
      # First catalog an apparatus
      params = %{
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      assert {:ok, apparatus} = Apparatus.catalog_apparatus(params)

      # Edit only the title
      edit_params = %{id: apparatus.id, title: "Updated Vaulting Table"}
      assert {:ok, updated} = Apparatus.edit_apparatus(edit_params)

      assert updated.title == "Updated Vaulting Table"
      assert updated.slug == "vaulting-table"
      assert updated.description == "A gymnastics vault"
    end

    test "edits an apparatus slug successfully" do
      params = %{title: "Pommel Horse", slug: "pommel-horse"}
      assert {:ok, apparatus} = Apparatus.catalog_apparatus(params)

      edit_params = %{id: apparatus.id, slug: "pommel-horse-updated"}
      assert {:ok, updated} = Apparatus.edit_apparatus(edit_params)

      assert updated.title == "Pommel Horse"
      assert updated.slug == "pommel-horse-updated"
    end

    test "edits an apparatus description successfully" do
      params = %{title: "Balance Beam", slug: "balance-beam"}
      assert {:ok, apparatus} = Apparatus.catalog_apparatus(params)

      edit_params = %{id: apparatus.id, description: "A narrow beam"}
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

  @spec new_apparatus(ApparatusReadModel.t()) ::
          {:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}
  defp new_apparatus(attributes) do
    ApparatusReadModel.insert_changeset(%ApparatusReadModel{}, attributes)
    |> Repo.insert()
  end

  defp new_apparatuses(attribute_collection) do
    Enum.each(attribute_collection, fn elem -> new_apparatus(elem) end)
  end
end
