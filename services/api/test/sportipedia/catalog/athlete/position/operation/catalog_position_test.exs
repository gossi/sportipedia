defmodule Sportipedia.Catalog.Athlete.Position.Operation.CatalogPositionTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Command.CatalogPosition
  alias Sportipedia.Catalog.Athlete.Position.Command.CatalogPositionHandler
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.Policy
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  alias Sportipedia.Catalog.Athlete.Position.PositionProjector
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  @moduletag :integration

  describe "PositionCataloged event" do
    test "creates PositionCataloged with required fields" do
      event =
        struct!(PositionCataloged, %{
          id: UUID.uuid4(),
          title: "sample-title",
          slug: "sample-slug",
          apparatusId: UUID.uuid4(),
          description: "sample-description",
          instrumentId: UUID.uuid4()
        })

      assert event.id != nil
    end

    test "requires enforced fields" do
      assert_raise ArgumentError, fn ->
        struct!(PositionCataloged, %{})
      end
    end

    test "serializes to JSON" do
      event =
        struct!(PositionCataloged, %{
          id: UUID.uuid4(),
          title: "sample-title",
          slug: "sample-slug",
          apparatusId: UUID.uuid4(),
          description: "sample-description",
          instrumentId: UUID.uuid4()
        })

      assert {:ok, _json} = Jason.encode(event)
    end
  end

  describe "CatalogPositionHandler" do
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
  end

  describe "PositionAggregate" do
    test "applies position-cataloged to aggregate state" do
      event = %PositionCataloged{
        id: UUID.uuid4(),
        title: "sample-title",
        slug: "sample-slug",
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4()
      }

      result = PositionAggregate.apply(%PositionAggregate{}, event)

      assert result.id == event.id
      assert result.title == event.title
      assert result.slug == event.slug
      assert result.apparatusId == event.apparatusId
      assert result.description == event.description
      assert result.instrumentId == event.instrumentId
    end
  end

  describe "CatalogPosition command" do
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

  describe "Policy - catalog_position" do
    test "denies or allows guests for catalog_position" do
      assert Policy.authorize(:catalog_position, nil, %{}) == :error
    end

    test "allows users for catalog_position" do
      assert Policy.authorize(:catalog_position, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
    end
  end

  describe "PositionProjector - PositionCataloged" do
    test "projects PositionCataloged to the position read model" do
      event = %PositionCataloged{
        id: UUID.uuid4(),
        title: "sample-title",
        slug: "sample-slug",
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4()
      }

      metadata = %{
        handler_name: "athlete.position_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "position-#{event.id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = PositionProjector.handle(event, metadata)

      assert Repo.get(PositionReadModel, event.id) != nil
    end
  end

  describe "Public API - catalog_position" do
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
  end
end
