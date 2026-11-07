defmodule Sportipedia.Catalog.Athlete.Position.Event.PositionCatalogedTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  alias Sportipedia.Catalog.Athlete.Position.PositionProjector
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  @moduletag :integration
  describe "Event" do
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

  describe "Aggregate" do
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

  describe "Projector" do
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
end
