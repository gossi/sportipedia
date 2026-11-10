defmodule Sportipedia.Catalog.Athlete.Position.Event.PositionArchivedTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionArchived
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  alias Sportipedia.Catalog.Athlete.Position.PositionProjector
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  @moduletag :integration
  describe "Event" do
    test "creates PositionArchived with required fields" do
      event =
        struct!(PositionArchived, %{id: UUID.uuid5(:dns, "athlete:position:unicycle-riding")})

      assert event.id != nil
    end

    test "requires enforced fields" do
      assert_raise ArgumentError, fn ->
        struct!(PositionArchived, %{})
      end
    end

    test "serializes to JSON" do
      event =
        struct!(PositionArchived, %{id: UUID.uuid5(:dns, "athlete:position:unicycle-riding")})

      assert {:ok, _json} = Jason.encode(event)
    end
  end

  describe "Aggregate" do
    test "applies position-archived to aggregate state" do
      event = %PositionArchived{id: UUID.uuid5(:dns, "athlete:position:unicycle-riding")}

      result = PositionAggregate.apply(%PositionAggregate{id: event.id}, event)

      assert is_nil(result)
    end
  end

  describe "Projector" do
    test "projects PositionArchived to the position read model" do
      create_event = %PositionCataloged{
        id: UUID.uuid5(:dns, "athlete:position:unicycle-riding"),
        title: "Riding",
        slug: "riding",
        apparatusId: UUID.uuid4(),
        description: "Riding on a unicycle",
        instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle")
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

      event = %PositionArchived{id: create_event.id}

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

      assert Repo.get(PositionReadModel, event.id) == nil
    end
  end
end
