defmodule Sportipedia.Catalog.Athlete.Position.Event.PositionEditedTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionEdited
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  alias Sportipedia.Catalog.Athlete.Position.PositionProjector
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  @moduletag :integration
  describe "Event" do
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

    test "get_changes returns only the fields the event carries" do
      id = UUID.uuid4()

      assert PositionEdited.get_changes(%PositionEdited{id: id, title: "New Title"}) == %{
               title: "New Title"
             }

      assert PositionEdited.get_changes(%PositionEdited{id: id}) == %{}
    end
  end

  describe "Aggregate" do
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

  describe "Projector" do
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

    test "an edit projection rewrites only the fields the event carries" do
      apparatus_id = UUID.uuid4()

      create_event = %PositionCataloged{
        id: UUID.uuid4(),
        title: "Old Title",
        slug: "old-title",
        description: "Unchanged description",
        apparatusId: apparatus_id
      }

      assert :ok = PositionProjector.handle(create_event, edit_metadata(create_event, 1))

      edit_event = %PositionEdited{id: create_event.id, title: "New Title"}
      assert :ok = PositionProjector.handle(edit_event, edit_metadata(edit_event, 2))

      position = Repo.get(PositionReadModel, edit_event.id)
      assert position.title == "New Title"
      assert position.slug == "old-title"
      assert position.description == "Unchanged description"
      assert position.apparatusId == apparatus_id
    end

    test "an edit projection over a position that is not there is a no-op" do
      edit_event = %PositionEdited{id: UUID.uuid4(), title: "Nobody"}

      assert :ok = PositionProjector.handle(edit_event, edit_metadata(edit_event, 1))
      assert Repo.get(PositionReadModel, edit_event.id) == nil
    end
  end

  defp edit_metadata(event, event_number) do
    %{
      handler_name: "athlete.position_projection",
      event_number: event_number,
      event_id: UUID.uuid4(),
      stream_id: "position-#{event.id}",
      stream_version: event_number,
      correlation_id: nil,
      causation_id: nil,
      created_at: DateTime.utc_now(),
      application: Sportipedia.Catalog,
      state: nil
    }
  end
end
