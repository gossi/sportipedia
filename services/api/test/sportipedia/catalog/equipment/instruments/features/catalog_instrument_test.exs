defmodule Sportipedia.Catalog.Equipment.Instruments.Feature.CatalogInstrumentTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Instruments
  alias Sportipedia.Catalog.Equipment.Instruments.Policy
  alias Sportipedia.Catalog.Equipment.Instruments.Command.CatalogInstrument
  alias Sportipedia.Catalog.Equipment.Instruments.Command.CatalogInstrumentHandler
  alias Sportipedia.Catalog.Equipment.Instruments.Event.InstrumentCataloged
  alias Sportipedia.Catalog.Equipment.Instruments.Aggregate.Instrument, as: InstrumentAggregate
  alias Sportipedia.Catalog.Equipment.Instruments.ReadModel.Instrument, as: InstrumentReadModel
  alias Sportipedia.Catalog.Repo

  describe "Policy" do
    @tag :unit
    test "allows authenticated user to catalog an instrument" do
      assert Policy.authorize(:catalog_instrument, %{id: "user-123"}, %{}) == :ok
    end

    @tag :unit
    test "rejects unauthenticated user" do
      assert Policy.authorize(:catalog_instrument, nil, %{}) == :error
    end
  end

  describe "Command validation" do
    @tag :unit
    test "is valid with all required fields" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), title: "Tennis Racket", slug: "tennis-racket")

      assert Vex.valid?(cmd)
    end

    @tag :unit
    test "is invalid without title" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), slug: "tennis-racket")

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :title, _, _}, &1))
    end

    @tag :unit
    test "is invalid without slug" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), title: "Tennis Racket")

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :slug, _, _}, &1))
    end

    @tag :unit
    test "is valid when description is omitted" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), title: "Tennis Racket", slug: "tennis-racket")

      assert Vex.valid?(cmd)
    end

    @tag :integration
    test "is invalid with duplicate slug" do
      slug = "tennis-racket"

      InstrumentReadModel.insert_changeset(%{id: UUID.uuid4(), title: "Existing", slug: slug})
      |> Repo.insert!()

      cmd = CatalogInstrument.new(id: UUID.uuid4(), title: "Tennis Racket", slug: slug)

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :slug, _, "slug already exists"}, &1))
    end
  end

  describe "Handler" do
    @tag :unit
    test "creates InstrumentCataloged event from CatalogInstrument command" do
      cmd =
        CatalogInstrument.new(
          id: "cmd-1",
          title: "Unicycle",
          slug: "unicycle",
          description: "Best vehicle in the world"
        )

      aggregate = %InstrumentAggregate{}

      assert %InstrumentCataloged{
               id: "cmd-1",
               title: "Unicycle",
               slug: "unicycle",
               description: "Best vehicle in the world"
             } = CatalogInstrumentHandler.handle(aggregate, cmd)
    end

    @tag :unit
    test "copies all fields from command to event" do
      cmd =
        CatalogInstrument.new(
          id: "cmd-2",
          title: "Skateboard",
          slug: "skateboard",
          description: "desc"
        )

      event = CatalogInstrumentHandler.handle(%InstrumentAggregate{}, cmd)

      assert event.id == cmd.id
      assert event.title == cmd.title
      assert event.slug == cmd.slug
      assert event.description == cmd.description
    end
  end

  describe "Event" do
    @tag :unit
    test "struct has all enforced fields" do
      event = %InstrumentCataloged{id: "e-1", title: "Hockey Stick", slug: "hockey-stick"}

      assert event.title == "Hockey Stick"
      assert event.slug == "hockey-stick"
    end

    @tag :unit
    test "can be encoded to JSON" do
      event = %InstrumentCataloged{
        id: "e-2",
        title: "Unicycle",
        slug: "unicycle",
        description: "Best vehicle in the world"
      }

      encoded = Jason.encode!(event)

      assert encoded =~ ~s("title":"Unicycle")
      assert encoded =~ ~s("slug":"unicycle")
      assert encoded =~ ~s("description":"Best vehicle in the world")
    end
  end

  describe "Aggregate" do
    @tag :unit
    test "creates aggregate state from InstrumentCataloged event" do
      event = %InstrumentCataloged{
        id: "agg-1",
        title: "Unicycle",
        slug: "unicycle",
        description: "Best vehicle in the world"
      }

      result = InstrumentAggregate.apply(%InstrumentAggregate{}, event)

      assert result.title == "Unicycle"
      assert result.slug == "unicycle"
      assert result.description == "Best vehicle in the world"
    end

    @tag :unit
    test "id is not propagated from event to aggregate state" do
      event = %InstrumentCataloged{id: "agg-id", title: "Beam", slug: "beam"}

      result = InstrumentAggregate.apply(%InstrumentAggregate{}, event)

      assert result.id == "agg-id"
    end
  end

  describe "Projector" do
    @tag :integration
    test "inserts instrument into catalog database" do
      event = %InstrumentCataloged{
        id: UUID.uuid4(),
        title: "Tennis Racket",
        slug: "tennis-racket",
        description: "A standard tennis racket"
      }

      changeset = InstrumentReadModel.insert_changeset(Map.from_struct(event))

      assert {:ok, %{catalog_instrument: instrument}} =
               Repo.transaction(
                 Ecto.Multi.new()
                 |> Ecto.Multi.insert(:catalog_instrument, changeset)
               )

      assert instrument.title == "Tennis Racket"
      assert instrument.slug == "tennis-racket"
      assert instrument.description == "A standard tennis racket"
    end

    @tag :integration
    test "rejects duplicate slug on insert" do
      slug = "tennis-racket"
      id = UUID.uuid4()

      InstrumentReadModel.insert_changeset(%{id: UUID.uuid4(), title: "Existing", slug: slug})
      |> Repo.insert!()

      event = %InstrumentCataloged{
        id: id,
        title: "Tennis Racket",
        slug: slug,
        description: "Another tennis racket"
      }

      changeset = InstrumentReadModel.insert_changeset(Map.from_struct(event))

      assert {:error, :catalog_instrument, _, _} =
               Repo.transaction(
                 Ecto.Multi.new()
                 |> Ecto.Multi.insert(:catalog_instrument, changeset)
               )
    end
  end

  describe "End-to-end" do
    @tag :integration
    test "dispatches CatalogInstrument through the router" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), title: "Uneven Bars", slug: "uneven-bars")

      assert :ok = Sportipedia.Catalog.dispatch(cmd, consistency: :strong)
    end

    @tag :integration
    test "validation failure is rejected before reaching the aggregate" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), slug: "unicycle")

      assert {:error, {:validation_failure, %{title: ["must be present"]}}} =
               Sportipedia.Catalog.dispatch(cmd)
    end

    @tag :integration
    test "catalog_instrument/1 creates an instrument through the public API" do
      params = %{
        title: "Vault Table",
        slug: "vault-table",
        description: "A standard vault table"
      }

      assert {:ok, instrument} = Instruments.catalog_instrument(params)
      assert instrument.title == "Vault Table"
      assert instrument.slug == "vault-table"
      assert instrument.description == "A standard vault table"
      assert is_binary(instrument.id)
    end
  end
end
