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
  alias Sportipedia.Catalog.Repo

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

    test "catalog_apparatus/1 catalogs an apparatus through the public API" do
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

  describe "Policy" do
    @describetag :unit

    test "allows authenticated user to catalog an apparatus" do
      assert Policy.authorize(:catalog_apparatus, %{id: "user-123"}, %{}) == :ok
    end

    test "rejects unauthenticated user" do
      assert Policy.authorize(:catalog_apparatus, nil, %{}) == :error
    end
  end

  describe "Command" do
    @describetag :unit

    test "is valid with all required fields" do
      cmd =
        CatalogApparatus.new(id: UUID.uuid4(), title: "Vaulting Table", slug: "vaulting-table")

      assert Vex.valid?(cmd)
    end

    test "raises when required struct fields are missing" do
      assert_raise ArgumentError, ~r"keys must also be given", fn ->
        struct!(CatalogApparatus, %{})
      end
    end

    test "is invalid without title" do
      cmd = CatalogApparatus.new(id: UUID.uuid4(), slug: "vaulting-table")

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :title, _, _}, &1))
    end

    test "is invalid without slug" do
      cmd = CatalogApparatus.new(id: UUID.uuid4(), title: "Vaulting Table")

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :slug, _, _}, &1))
    end

    test "is valid when description is omitted" do
      cmd =
        CatalogApparatus.new(id: UUID.uuid4(), title: "Vaulting Table", slug: "vaulting-table")

      assert Vex.valid?(cmd)
    end

    @tag :integration
    test "is invalid with duplicate slug" do
      slug = "vaulting-table"

      ApparatusReadModel.insert_changeset(%ApparatusReadModel{}, %{
        id: UUID.uuid4(),
        title: "Existing",
        slug: slug
      })
      |> Repo.insert!()

      cmd = CatalogApparatus.new(id: UUID.uuid4(), title: "Vaulting Table", slug: slug)

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :slug, _, "slug already exists"}, &1))
    end
  end

  describe "Projector" do
    @describetag :integration

    test "projects ApparatusCataloged event into the read model" do
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
        stream_id: "apparatus-#{event.id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(event, metadata)

      apparatus = Repo.get!(ApparatusReadModel, event.id)
      assert apparatus.title == "Vaulting Table"
      assert apparatus.slug == "vaulting-table"
      assert apparatus.description == "A gymnastics vault"
    end

    test "is idempotent for the same event" do
      event = %ApparatusCataloged{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "vaulting-table"
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

      assert [apparatus] = Repo.all(ApparatusReadModel)
      assert apparatus.id == event.id
    end

    test "rejects duplicate slug" do
      slug = "vaulting-table"

      Repo.insert!(%ApparatusReadModel{id: UUID.uuid4(), title: "Existing", slug: slug})

      event = %ApparatusCataloged{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: slug
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

      assert {:error, _} = ApparatusProjector.handle(event, metadata)
    end
  end

  describe "Command Handler" do
    @describetag :unit

    test "creates ApparatusCataloged event from CatalogApparatus command" do
      cmd =
        CatalogApparatus.new(
          id: "cmd-1",
          title: "Vaulting Table",
          slug: "vaulting-table",
          description: "A gymnastics vault"
        )

      aggregate = %ApparatusAggregate{}

      assert %ApparatusCataloged{
               id: "cmd-1",
               title: "Vaulting Table",
               slug: "vaulting-table",
               description: "A gymnastics vault"
             } = CatalogApparatusHandler.handle(aggregate, cmd)
    end

    test "copies all fields from command to event" do
      cmd =
        CatalogApparatus.new(
          id: "cmd-2",
          title: "Pommel Horse",
          slug: "pommel-horse",
          description: "desc"
        )

      event = CatalogApparatusHandler.handle(%ApparatusAggregate{}, cmd)

      assert event.id == cmd.id
      assert event.title == cmd.title
      assert event.slug == cmd.slug
      assert event.description == cmd.description
    end
  end

  describe "Aggregate" do
    @describetag :unit

    test "applies ApparatusCataloged event to aggregate state" do
      event = %ApparatusCataloged{
        id: "agg-1",
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      result = ApparatusAggregate.apply(%ApparatusAggregate{}, event)

      assert result.id == "agg-1"
      assert result.title == "Vaulting Table"
      assert result.slug == "vaulting-table"
      assert result.description == "A gymnastics vault"
    end
  end

  describe "Event" do
    @describetag :unit

    test "struct has enforced fields" do
      assert_raise ArgumentError, ~r"keys must also be given", fn ->
        struct!(ApparatusCataloged, %{})
      end
    end

    test "can be encoded to JSON" do
      event = %ApparatusCataloged{
        id: "e-1",
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      encoded = Jason.encode!(event)

      assert encoded =~ ~s("title":"Vaulting Table")
      assert encoded =~ ~s("slug":"vaulting-table")
      assert encoded =~ ~s("description":"A gymnastics vault")
    end

    test "can be encoded to JSON without optional description" do
      event = %ApparatusCataloged{
        id: "e-2",
        title: "Vaulting Table",
        slug: "vaulting-table"
      }

      encoded = Jason.encode!(event)

      assert encoded =~ ~s("title":"Vaulting Table")
      assert encoded =~ ~s("slug":"vaulting-table")
    end
  end
end
