defmodule Sportipedia.Catalog.Athlete.Position.Operation.CatalogPositionTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Command.CatalogPosition
  alias Sportipedia.Catalog.Athlete.Position.Command.CatalogPositionHandler
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.Policy
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Instrument
  @moduletag :integration
  describe "Command" do
    test "requires id" do
      assert_raise ArgumentError, fn ->
        struct!(CatalogPosition, %{})
      end
    end

    test "validates presence of title" do
      cmd = %CatalogPosition{
        id: UUID.uuid4(),
        slug: "sample-slug",
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4(),
        title: nil
      }

      assert {:error, _errors} = Vex.validate(cmd)
    end

    test "validates presence of slug" do
      cmd = %CatalogPosition{
        id: UUID.uuid4(),
        title: "sample-title",
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4(),
        slug: nil
      }

      assert {:error, _errors} = Vex.validate(cmd)
    end
  end

  describe "Command Handler" do
    test "handles CatalogPosition command and returns PositionCataloged event" do
      cmd = %CatalogPosition{
        id: UUID.uuid4(),
        title: "sample-title",
        slug: "sample-slug",
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4()
      }

      events = CatalogPositionHandler.handle(%PositionAggregate{}, cmd)

      assert %PositionCataloged{} = events
    end

    test "maps every command field onto the PositionCataloged event" do
      apparatus_id = UUID.uuid4()

      cmd = %CatalogPosition{
        id: UUID.uuid4(),
        title: "Handstand",
        slug: "handstand",
        description: "Inverted balance on the hands",
        apparatusId: apparatus_id,
        instrumentId: nil
      }

      event = CatalogPositionHandler.handle(%PositionAggregate{}, cmd)

      assert %PositionCataloged{id: id, title: "Handstand"} = event
      assert id == cmd.id
      assert event.title == cmd.title
      assert event.slug == cmd.slug
      assert event.description == cmd.description
      assert event.apparatusId == apparatus_id
      assert event.instrumentId == nil
    end
  end

  describe "Policy" do
    test "denies or allows guests for catalog_position" do
      assert Policy.authorize(:catalog_position, nil, %{}) == :error
    end

    test "allows users for catalog_position" do
      assert Policy.authorize(:catalog_position, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
    end
  end

  describe "Public API" do
    test "catalog_position succeeds" do
      assert {:ok, read_model} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "sample-slug-#{UUID.uuid4()}"
               })

      assert read_model.id != nil
    end

    test "catalog_position returns validation errors" do
      assert {:error, {:validation_failure, _errors}} = Position.catalog_position(%{})
    end

    test "catalogs a position without equipment, with no equipment reference" do
      slug = "ready-stance-#{UUID.uuid4()}"

      assert {:ok, position} =
               Position.catalog_position(%{
                 title: "Ready Stance",
                 slug: slug,
                 description: "Athletic stance with knees slightly bent"
               })

      assert position.title == "Ready Stance"
      assert position.slug == slug
      assert position.description == "Athletic stance with knees slightly bent"
      assert position.apparatusId == nil
      assert position.instrumentId == nil

      # The position is available in the read model, not only in the response.
      assert {:ok, read_back} = Position.read_position(position.id)
      assert read_back.id == position.id
      assert read_back.apparatusId == nil
      assert read_back.instrumentId == nil
    end

    test "catalogs a position that references an apparatus" do
      {:ok, apparatus} =
        Apparatus.catalog_apparatus(%{title: "Starting Blocks", slug: "starting-blocks"})

      slug = "starting-block-position-#{UUID.uuid4()}"

      assert {:ok, position} =
               Position.catalog_position(%{
                 title: "Starting Block Position",
                 slug: slug,
                 apparatusId: apparatus.id
               })

      assert position.apparatusId == apparatus.id
      assert position.instrumentId == nil

      assert {:ok, read_back} = Position.read_position(position.id)
      assert read_back.apparatusId == apparatus.id
    end

    test "rejects a slug another position already has and emits no event" do
      slug = "guard-position-#{UUID.uuid4()}"
      {:ok, _existing} = Position.catalog_position(%{title: "Guard Position", slug: slug})

      assert {:error, {:validation_failure, failures}} =
               Position.catalog_position(%{title: "Another Guard Position", slug: slug})

      assert failures == %{slug: [:slug_exists]}

      # No event was emitted, so nothing was projected either.
      assert Repo.aggregate(PositionReadModel, :count) == 1
    end

    test "rejects a position that references both an apparatus and an instrument" do
      {:ok, apparatus} = Apparatus.catalog_apparatus(%{title: "Vault", slug: "vault"})

      {:ok, instrument} =
        Instrument.catalog_instrument(%{title: "Shuttlecock", slug: "shuttlecock"})

      assert {:error, {:validation_failure, failures}} =
               Position.catalog_position(%{
                 title: "Impossible Position",
                 slug: "impossible-#{UUID.uuid4()}",
                 apparatusId: apparatus.id,
                 instrumentId: instrument.id
               })

      assert failures == %{instrumentId: [:at_most_one_equipment]}
      assert Repo.aggregate(PositionReadModel, :count) == 0
    end

    test "leaves an absent slug to the presence check, not to the unique-slug validator" do
      # Vex does not short-circuit: without `allow_nil` on the validator pair the
      # unique-slug check would be called with nil and crash on String.downcase/1.
      assert {:error, {:validation_failure, failures}} =
               Position.catalog_position(%{title: "No Slug", slug: nil})

      assert failures == %{slug: ["must be present"]}
    end

    test "rejects an apparatus reference that is not in the catalog" do
      assert {:error, {:validation_failure, failures}} =
               Position.catalog_position(%{
                 title: "Phantom Apparatus Position",
                 slug: "phantom-apparatus-#{UUID.uuid4()}",
                 apparatusId: UUID.uuid4()
               })

      assert failures == %{apparatusId: [:equipment_not_found]}
      assert Repo.aggregate(PositionReadModel, :count) == 0
    end

    test "rejects an instrument reference that is not in the catalog" do
      assert {:error, {:validation_failure, failures}} =
               Position.catalog_position(%{
                 title: "Phantom Instrument Position",
                 slug: "phantom-instrument-#{UUID.uuid4()}",
                 instrumentId: UUID.uuid4()
               })

      assert failures == %{instrumentId: [:equipment_not_found]}
    end

    test "rejects an equipment reference that was archived: an archived equipment is not found" do
      {:ok, apparatus} =
        Apparatus.catalog_apparatus(%{title: "Pommel Horse", slug: "pommel-horse"})

      :ok = Apparatus.archive_apparatus(apparatus.id)

      assert {:error, {:validation_failure, failures}} =
               Position.catalog_position(%{
                 title: "Pommel Position",
                 slug: "pommel-position-#{UUID.uuid4()}",
                 apparatusId: apparatus.id
               })

      assert failures == %{apparatusId: [:equipment_not_found]}
    end
  end
end
