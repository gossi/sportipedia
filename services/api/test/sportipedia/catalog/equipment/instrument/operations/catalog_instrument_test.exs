defmodule Sportipedia.Catalog.Equipment.Instrument.Feature.CatalogInstrumentTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.Instrument
  alias Sportipedia.Catalog.Equipment.Instrument.Policy
  alias Sportipedia.Catalog.Equipment.Instrument.Command.CatalogInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.Command.CatalogInstrumentHandler
  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentCataloged
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentAggregate
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  alias Sportipedia.Catalog.Repo

  import Sportipedia.TestSupport.Catalog.Equipment

  alias Sportipedia.TestSupport.Catalog.Equipment.ApparatusFixtures
  alias Sportipedia.TestSupport.Catalog.Equipment.InstrumentFixtures

  describe "Policy" do
    @describetag :unit

    test "allows authenticated user to catalog an instrument" do
      assert Policy.authorize(:catalog_instrument, %{id: "user-123"}, %{}) == :ok
    end

    test "rejects unauthenticated user" do
      assert Policy.authorize(:catalog_instrument, nil, %{}) == :error
    end
  end

  describe "Command" do
    @describetag :unit

    test "is valid with all required fields" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), title: "Tennis Racket", slug: "tennis-racket")

      assert Vex.valid?(cmd)
    end

    test "raises when required struct fields are missing" do
      assert_raise ArgumentError, ~r"keys must also be given", fn ->
        struct!(CatalogInstrument, %{})
      end
    end

    test "is invalid without title" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), slug: "tennis-racket")

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :title, _, _}, &1))
    end

    test "is invalid without slug" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), title: "Tennis Racket")

      refute Vex.valid?(cmd)
      assert Enum.any?(Vex.errors(cmd), &match?({:error, :slug, _, _}, &1))
    end

    test "is invalid when the slug is not lower-case" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), title: "Tennis Racket", slug: "Tennis-Racket")

      refute Vex.valid?(cmd)
      assert {:error, :slug, :by, :invalid_slug} in Vex.errors(cmd)
    end

    test "is valid when description is omitted" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), title: "Tennis Racket", slug: "tennis-racket")

      assert Vex.valid?(cmd)
    end

    @tag :integration
    test "is invalid with duplicate slug" do
      new_instrument(InstrumentFixtures.unicycle())

      cmd = CatalogInstrument.new(id: UUID.uuid4(), title: "Tennis Racket", slug: "unicycle")

      assert {:error, [{:error, :slug, :by, :slug_exists}]} =
               Vex.validate(cmd)
    end

    @tag :integration
    test "is invalid with a slug already used by an apparatus" do
      new_apparatus(ApparatusFixtures.balance_beam())

      cmd = CatalogInstrument.new(id: UUID.uuid4(), title: "Tennis Racket", slug: "balance-beam")

      assert {:error, [{:error, :slug, :by, :slug_exists}]} =
               Vex.validate(cmd)
    end
  end

  describe "Command Handler" do
    @describetag :unit

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

  describe "Public API" do
    @describetag :integration

    test "dispatches CatalogInstrument through the router" do
      id = UUID.uuid4()
      cmd = CatalogInstrument.new(id: id, title: "Unicycle", slug: "unicycle")

      assert :ok = Sportipedia.Catalog.dispatch(cmd, consistency: :strong)

      assert %InstrumentReadModel{title: "Unicycle", slug: "unicycle"} =
               Repo.get(InstrumentReadModel, id)
    end

    test "validation failure is rejected before reaching the aggregate" do
      cmd = CatalogInstrument.new(id: UUID.uuid4(), slug: "unicycle")

      assert {:error, {:validation_failure, %{title: ["must be present"]}}} =
               Sportipedia.Catalog.dispatch(cmd)
    end

    test "catalog_instrument/1 creates an instrument through the public API" do
      params = %{
        title: "Unicycle",
        slug: "unicycle",
        description: "Best vehicle in the world"
      }

      assert {:ok, instrument} = Instrument.catalog_instrument(params)
      assert instrument.title == "Unicycle"
      assert instrument.slug == "unicycle"
      assert instrument.description == "Best vehicle in the world"
      assert is_binary(instrument.id)
    end
  end
end
