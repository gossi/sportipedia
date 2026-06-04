defmodule Sportipedia.Catalog.Equipment.Apparatus.Operation.EditApparatusTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatusHandler
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy
  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Repo

  describe "EditApparatus command" do
    @describetag :unit

    test "creates command with enforced id" do
      assert_raise ArgumentError, fn ->
        struct!(EditApparatus, %{})
      end
    end

    test "creates command with id only" do
      cmd = %EditApparatus{id: "d290f1ee-6c54-4b01-90e6-d701748f0851"}
      assert cmd.id == "d290f1ee-6c54-4b01-90e6-d701748f0851"
      assert cmd.title == nil
      assert cmd.slug == nil
      assert cmd.description == nil
    end

    test "creates command with all optional fields" do
      cmd = %EditApparatus{
        id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
        title: "Vault",
        slug: "vault",
        description: "A gymnastics vault"
      }
      assert cmd.title == "Vault"
      assert cmd.slug == "vault"
      assert cmd.description == "A gymnastics vault"
    end
  end

  describe "Public API" do
    @describetag :integration

    setup do
      # Create an initial apparatus record
      apparatus = %ApparatusReadModel{
        id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }
      Repo.insert!(apparatus)
      %{apparatus: apparatus}
    end

    test "successfully edits an apparatus", %{apparatus: apparatus} do
      assert {:ok, updated} = Apparatus.edit_apparatus(%{
        id: apparatus.id,
        title: "Vault"
      })

      assert updated.title == "Vault"
      assert updated.slug == "vaulting-table"
      assert updated.description == "A gymnastics vault"
    end

    test "returns error when id is missing" do
      assert {:error, _reason} = Apparatus.edit_apparatus(%{
        title: "Vault"
      })
    end

    test "rejects duplicate slug when slug is changed", %{apparatus: apparatus} do
      # Create another apparatus with the slug we want to use
      other = %ApparatusReadModel{
        id: "e290f1ee-6c54-4b01-90e6-d701748f0852",
        title: "Balance Beam",
        slug: "balance-beam",
        description: "A balance beam"
      }
      Repo.insert!(other)

      assert {:error, {:validation_failure, %{slug: ["slug already exists"]}}} =
               Apparatus.edit_apparatus(%{
                 id: apparatus.id,
                 slug: "balance-beam"
               })
    end
  end

  describe "Projector" do
    @describetag :integration

    setup do
      # Create an initial apparatus record
      apparatus = %ApparatusReadModel{
        id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }
      Repo.insert!(apparatus)
      %{apparatus: apparatus}
    end

    test "updates read model on apparatus-edited event", %{apparatus: apparatus} do
      event = %ApparatusEdited{
        id: apparatus.id,
        title: "Vault"
      }

      metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 1,
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

      updated = Repo.get!(ApparatusReadModel, event.id)
      assert updated.title == "Vault"
      assert updated.slug == "vaulting-table"
      assert updated.description == "A gymnastics vault"
    end

    test "is idempotent", %{apparatus: apparatus} do
      event = %ApparatusEdited{
        id: apparatus.id,
        title: "Vault"
      }

      metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 1,
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
      assert :ok = ApparatusProjector.handle(event, metadata)

      assert [%ApparatusReadModel{}] = Repo.all(ApparatusReadModel)
    end
  end

  describe "Policy" do
    @describetag :unit

    test "allows user to edit apparatus" do
      user = %{id: "user-1"}
      assert Policy.authorize(:edit_apparatus, user, nil) == :ok
    end

    test "denies guest from editing apparatus" do
      assert Policy.authorize(:edit_apparatus, nil, nil) == :error
    end
  end

  describe "EditApparatusHandler" do
    @describetag :unit

    test "creates ApparatusEdited event with only changed fields" do
      cmd = %EditApparatus{
        id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
        title: "Vault"
      }

      assert %ApparatusEdited{} = event = EditApparatusHandler.handle(%ApparatusAggregate{}, cmd)
      assert event.id == "d290f1ee-6c54-4b01-90e6-d701748f0851"
      assert event.title == "Vault"
      assert event.slug == nil
      assert event.description == nil
    end

    test "creates ApparatusEdited event with all provided fields" do
      cmd = %EditApparatus{
        id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
        title: "Vault",
        slug: "vault",
        description: "Updated description"
      }

      assert %ApparatusEdited{} = event = EditApparatusHandler.handle(%ApparatusAggregate{}, cmd)
      assert event.id == "d290f1ee-6c54-4b01-90e6-d701748f0851"
      assert event.title == "Vault"
      assert event.slug == "vault"
      assert event.description == "Updated description"
    end
  end

  describe "ApparatusAggregate" do
    @describetag :unit

    test "applies apparatus-edited event preserving nil fields as unchanged" do
      aggregate = %ApparatusAggregate{
        id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      event = %ApparatusEdited{
        id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
        title: "Vault"
      }

      result = ApparatusAggregate.apply(aggregate, event)
      assert result.title == "Vault"
      assert result.slug == "vaulting-table"
      assert result.description == "A gymnastics vault"
    end

    test "applies apparatus-edited event with all fields" do
      aggregate = %ApparatusAggregate{
        id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      event = %ApparatusEdited{
        id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
        title: "Vault",
        slug: "vault",
        description: "Updated description"
      }

      result = ApparatusAggregate.apply(aggregate, event)
      assert result.title == "Vault"
      assert result.slug == "vault"
      assert result.description == "Updated description"
    end
  end

  describe "ApparatusEdited event" do
    @describetag :unit

    test "creates event with enforced id" do
      assert_raise ArgumentError, fn ->
        struct!(ApparatusEdited, %{})
      end
    end

    test "creates event with id only" do
      event = %ApparatusEdited{id: "d290f1ee-6c54-4b01-90e6-d701748f0851"}
      assert event.id == "d290f1ee-6c54-4b01-90e6-d701748f0851"
      assert event.title == nil
      assert event.slug == nil
      assert event.description == nil
    end

    test "creates event with all fields" do
      event = %ApparatusEdited{
        id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
        title: "Vault",
        slug: "vault",
        description: "A gymnastics vault"
      }
      assert event.title == "Vault"
      assert event.slug == "vault"
      assert event.description == "A gymnastics vault"
    end

    test "serializes to JSON" do
      event = %ApparatusEdited{
        id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
        title: "Vault"
      }

      json = Jason.encode!(event)
      assert json =~ ~s("id":)
      assert json =~ ~s("title":)
      assert json =~ ~s("Vault")
    end
  end
end
