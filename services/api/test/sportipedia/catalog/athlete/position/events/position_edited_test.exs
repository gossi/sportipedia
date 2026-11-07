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

    test "holds only the fields the patch carried in its change set" do
      id = UUID.uuid4()

      event = %PositionEdited{
        id: id,
        title: "New Title",
        apparatusId: UUID.uuid4()
      }

      changes = PositionEdited.get_changes(event)

      assert changes == %{title: event.title, apparatusId: event.apparatusId}
      refute Map.has_key?(changes, :id)
      refute Map.has_key?(changes, :slug)
      refute Map.has_key?(changes, :description)
      refute Map.has_key?(changes, :instrumentId)
    end

    test "answers an empty change set for a patch that carried nothing but the address" do
      assert PositionEdited.get_changes(%PositionEdited{id: UUID.uuid4()}) == %{}
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

    test "keeps what the position-edited patch did not carry" do
      id = UUID.uuid4()

      cataloged = %PositionCataloged{
        id: id,
        title: "Old Title",
        slug: "old-slug",
        description: "Old description",
        apparatusId: UUID.uuid4()
      }

      aggregate = PositionAggregate.apply(%PositionAggregate{}, cataloged)

      edited = %PositionEdited{
        id: id,
        title: "New Title"
      }

      result = PositionAggregate.apply(aggregate, edited)

      assert result.title == "New Title"
      assert result.slug == aggregate.slug
      assert result.description == "Old description"
      assert result.apparatusId == cataloged.apparatusId
      assert result.instrumentId == nil
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

    test "leaves the equipment reference alone for an edit that does not carry one" do
      apparatus_id = UUID.uuid4()

      create_event = %PositionCataloged{
        id: UUID.uuid4(),
        title: "Old Title",
        slug: "old-slug",
        description: "Old description",
        apparatusId: apparatus_id
      }

      assert :ok =
               PositionProjector.handle(create_event, projection_metadata(create_event, 1))

      assert %PositionReadModel{} = before_edit = Repo.get(PositionReadModel, create_event.id)
      assert before_edit.apparatusId == apparatus_id

      event = %PositionEdited{id: create_event.id, title: "New Title"}

      assert :ok = PositionProjector.handle(event, projection_metadata(event, 2))

      position = Repo.get(PositionReadModel, event.id)

      assert position.title == "New Title"
      assert position.slug == "old-slug"
      assert position.description == "Old description"
      assert position.apparatusId == apparatus_id
      assert position.instrumentId == nil
    end

    test "ignores an edit for a position the catalog does not hold" do
      event = %PositionEdited{id: UUID.uuid4(), title: "New Title"}

      assert :ok = PositionProjector.handle(event, projection_metadata(event, 1))

      assert Repo.get(PositionReadModel, event.id) == nil
    end
  end

  defp projection_metadata(event, event_number) do
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
