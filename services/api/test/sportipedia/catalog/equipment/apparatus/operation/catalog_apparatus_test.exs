defmodule Sportipedia.Catalog.Equipment.Apparatus.Feature.CatalogApparatusTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Policy
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatusHandler
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector
  alias Sportipedia.Catalog.Repo

  describe "Policy" do
    @describetag :unit

    test "allows a user to catalog an apparatus" do
      assert Policy.authorize(:catalog_apparatus, %{}, %{}) == :ok
    end

    test "rejects unauthenticated user" do
      assert Policy.authorize(:catalog_apparatus, nil, %{}) == :error
    end
  end

  describe "Command" do
    @tag :unit
    test "creates a command with required fields" do
      cmd = CatalogApparatus.new(title: "Vaulting Table", slug: "vaulting-table")

      assert cmd.title == "Vaulting Table"
      assert cmd.slug == "vaulting-table"
      assert cmd.description == nil
    end

    @tag :unit
    test "creates a command with all fields" do
      cmd =
        CatalogApparatus.new(
          title: "Vaulting Table",
          slug: "vaulting-table",
          description: "A gymnastics vault"
        )

      assert cmd.description == "A gymnastics vault"
    end

    @tag :unit
    test "is valid with all required fields" do
      cmd =
        CatalogApparatus.new(id: UUID.uuid4(), title: "Vaulting Table", slug: "vaulting-table")

      assert Vex.valid?(cmd)
    end

    @tag :unit
    test "is invalid without title" do
      cmd = CatalogApparatus.new(id: UUID.uuid4(), slug: "vaulting-table")

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :title, _, _}, &1))
    end

    @tag :unit
    test "is invalid without slug" do
      cmd = CatalogApparatus.new(id: UUID.uuid4(), title: "Vaulting Table")

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :slug, _, _}, &1))
    end

    @tag :integration
    test "is invalid with duplicate slug" do
      slug = "vaulting-table"

      %ApparatusReadModel{id: UUID.uuid4(), title: "Existing", slug: slug}
      |> Repo.insert!()

      cmd = CatalogApparatus.new(id: UUID.uuid4(), title: "Another Vault", slug: slug)

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :slug, _, "slug already exists"}, &1))
    end
  end

  describe "Event" do
    @describetag :unit

    test "struct has enforced fields" do
      assert_raise ArgumentError, ~r"keys must also be given", fn ->
        struct!(ApparatusCataloged, %{})
      end
    end

    test "creates an event with required fields" do
      event =
        ApparatusCataloged.new(
          id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
          title: "Vaulting Table",
          slug: "vaulting-table"
        )

      assert event.id == "d290f1ee-6c54-4b01-90e6-d701748f0851"
      assert event.title == "Vaulting Table"
      assert event.slug == "vaulting-table"
      assert event.description == nil
    end

    test "can be encoded to JSON" do
      event =
        ApparatusCataloged.new(
          id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
          title: "Vaulting Table",
          slug: "vaulting-table",
          description: "A gymnastics vault"
        )

      encoded = Jason.encode!(event)

      assert encoded =~ ~s("title":"Vaulting Table")
      assert encoded =~ ~s("slug":"vaulting-table")
      assert encoded =~ ~s("description":"A gymnastics vault")
    end
  end

  describe "Aggregate" do
    @describetag :unit

    test "applies apparatus-cataloged event to aggregate state" do
      event =
        ApparatusCataloged.new(
          id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
          title: "Vaulting Table",
          slug: "vaulting-table",
          description: "A gymnastics vault"
        )

      result = ApparatusAggregate.apply(%ApparatusAggregate{}, event)

      assert result.id == "d290f1ee-6c54-4b01-90e6-d701748f0851"
      assert result.title == "Vaulting Table"
      assert result.slug == "vaulting-table"
      assert result.description == "A gymnastics vault"
    end

    test "id is propagated from event to aggregate state" do
      event = ApparatusCataloged.new(id: "agg-id", title: "Beam", slug: "beam")

      result = ApparatusAggregate.apply(%ApparatusAggregate{}, event)

      assert result.id == "agg-id"
    end
  end

  describe "Command Handler" do
    @describetag :unit

    test "produces apparatus-cataloged event from command" do
      cmd =
        CatalogApparatus.new(
          id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
          title: "Vaulting Table",
          slug: "vaulting-table",
          description: "A gymnastics vault"
        )

      event = CatalogApparatusHandler.handle(%ApparatusAggregate{}, cmd)

      assert event.id == "d290f1ee-6c54-4b01-90e6-d701748f0851"
      assert event.title == "Vaulting Table"
      assert event.slug == "vaulting-table"
      assert event.description == "A gymnastics vault"
    end

    test "copies all fields from command to event" do
      cmd =
        CatalogApparatus.new(
          id: "cmd-2",
          title: "Balance Beam",
          slug: "balance-beam",
          description: "desc"
        )

      event = CatalogApparatusHandler.handle(%ApparatusAggregate{}, cmd)

      assert event.id == cmd.id
      assert event.title == cmd.title
      assert event.slug == cmd.slug
      assert event.description == cmd.description
    end
  end

  describe "Projector" do
    @describetag :integration

    test "projects apparatus-cataloged event into the read model" do
      event =
        ApparatusCataloged.new(
          id: UUID.uuid4(),
          title: "Vaulting Table",
          slug: "vaulting-table",
          description: "A gymnastics vault"
        )

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

      record = Repo.get!(ApparatusReadModel, event.id)
      assert record.title == "Vaulting Table"
      assert record.slug == "vaulting-table"
      assert record.description == "A gymnastics vault"
    end

    test "is idempotent for the same event" do
      event =
        ApparatusCataloged.new(
          id: UUID.uuid4(),
          title: "Balance Beam",
          slug: "balance-beam"
        )

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

      assert [record] = Repo.all(ApparatusReadModel)
      assert record.id == event.id
    end

    test "rejects duplicate slug" do
      slug = "balance-beam"

      Repo.insert!(%ApparatusReadModel{id: UUID.uuid4(), title: "Existing", slug: slug})

      event =
        ApparatusCataloged.new(
          id: UUID.uuid4(),
          title: "Another Beam",
          slug: slug
        )

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

      assert {:error, _} = ApparatusProjector.handle(event, metadata)
    end
  end

  describe "Public API" do
    @describetag :integration

    test "dispatches CatalogApparatus through the router" do
      id = UUID.uuid4()
      cmd = CatalogApparatus.new(id: id, title: "Vaulting Table", slug: "vaulting-table")

      assert :ok = Sportipedia.Catalog.dispatch(cmd, consistency: :strong)

      assert %ApparatusReadModel{title: "Vaulting Table", slug: "vaulting-table"} =
               Repo.get(ApparatusReadModel, id)
    end

    test "validation failure is rejected before reaching the aggregate" do
      cmd = CatalogApparatus.new(id: UUID.uuid4(), slug: "vaulting-table")

      assert {:error, {:validation_failure, %{title: ["must be present"]}}} =
               Sportipedia.Catalog.dispatch(cmd)
    end

    test "catalog_apparatus/1 creates an apparatus through the public API" do
      params = %{
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      assert {:ok, apparatus} = Apparatus.catalog_apparatus(params)
      assert apparatus.title == "Vaulting Table"
      assert apparatus.slug == "vaulting-table"
      assert apparatus.description == "A gymnastics vault"
      assert is_binary(apparatus.id)
    end
  end
end
