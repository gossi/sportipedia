defmodule Sportipedia.Catalog.Athlete.Position.Operation.EditPositionTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Command.EditPosition
  alias Sportipedia.Catalog.Athlete.Position.Command.EditPositionHandler
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionEdited
  alias Sportipedia.Catalog.Athlete.Position.Policy
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  alias Sportipedia.Catalog.Athlete.Position.PositionProjector
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  @moduletag :integration

  describe "PositionEdited event" do
    test "creates PositionEdited with required fields" do
      event =
        struct!(PositionEdited, %{
          id: UUID.uuid4(),
          apparatusId: UUID.uuid4(),
          description: "sample-description",
          instrumentId: UUID.uuid4(),
          slug: "sample-slug",
          title: "sample-title"
        })

      assert event.id != nil
    end

    test "requires enforced fields" do
      assert_raise ArgumentError, fn ->
        struct!(PositionEdited, %{})
      end
    end

    test "serializes to JSON" do
      event =
        struct!(PositionEdited, %{
          id: UUID.uuid4(),
          apparatusId: UUID.uuid4(),
          description: "sample-description",
          instrumentId: UUID.uuid4(),
          slug: "sample-slug",
          title: "sample-title"
        })

      assert {:ok, _json} = Jason.encode(event)
    end
  end

  describe "EditPositionHandler" do
    test "handles EditPosition command and returns PositionEdited event" do
      cmd = %EditPosition{
        id: UUID.uuid4(),
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4(),
        slug: "sample-slug",
        title: "sample-title"
      }

      events = EditPositionHandler.handle(%PositionAggregate{}, cmd)

      assert %PositionEdited{} = events
    end
  end

  describe "PositionAggregate" do
    test "applies position-edited to aggregate state" do
      event = %PositionEdited{
        id: UUID.uuid4(),
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4(),
        slug: "sample-slug",
        title: "sample-title"
      }

      result = PositionAggregate.apply(%PositionAggregate{id: event.id}, event)

      assert result.id == event.id
      assert result.apparatusId == event.apparatusId
      assert result.description == event.description
      assert result.instrumentId == event.instrumentId
      assert result.slug == event.slug
      assert result.title == event.title
    end
  end

  describe "EditPosition command" do
    test "requires id" do
      assert_raise ArgumentError, fn ->
        struct!(EditPosition, %{})
      end
    end

    test "id cannot be nil" do
      cmd = %EditPosition{
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4(),
        slug: "sample-slug",
        title: "sample-title",
        id: nil
      }

      assert_raise ArgumentError, fn ->
        Vex.validate(cmd)
      end
    end
  end

  describe "Policy - edit_position" do
    test "denies or allows guests for edit_position" do
      assert Policy.authorize(:edit_position, nil, %{}) == :error
    end

    test "allows users for edit_position" do
      assert Policy.authorize(:edit_position, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
    end
  end

  describe "PositionProjector - PositionEdited" do
    test "projects PositionEdited to the position read model" do
      create_event = %PositionCataloged{
        id: UUID.uuid4(),
        title: "sample-title",
        slug: "sample-slug",
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4()
      }

      create_metadata = %{
        handler_name: "athlete.position_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "position-#{create_event.id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = PositionProjector.handle(create_event, create_metadata)

      event = %PositionEdited{
        id: create_event.id,
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4(),
        slug: "sample-slug",
        title: "sample-title"
      }

      metadata = %{
        handler_name: "athlete.position_projection",
        event_number: 2,
        event_id: UUID.uuid4(),
        stream_id: "position-#{event.id}",
        stream_version: 2,
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

  describe "Public API - edit_position" do
    test "edit_position succeeds" do
      assert {:ok, created} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "sample-slug-#{UUID.uuid4()}"
               })

      assert {:ok, read_model} = Position.edit_position(%{id: created.id})

      assert read_model.id == created.id
    end
  end
end
