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
      event = struct!(PositionArchived, %{id: UUID.uuid4()})

      assert event.id != nil
    end

    test "requires enforced fields" do
      assert_raise ArgumentError, fn ->
        struct!(PositionArchived, %{})
      end
    end

    test "serializes to JSON" do
      event = struct!(PositionArchived, %{id: UUID.uuid4()})

      assert {:ok, _json} = Jason.encode(event)
    end
  end

  describe "Aggregate" do
    test "applies position-archived to aggregate state" do
      event = %PositionArchived{id: UUID.uuid4()}

      result = PositionAggregate.apply(%PositionAggregate{id: event.id}, event)

      assert is_nil(result)
    end
  end

  describe "Projector" do
    test "projects PositionArchived to the position read model" do
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

    test "projecting PositionArchived for a position that is not in the catalog leaves nothing to remove" do
      create_event = %PositionCataloged{
        id: UUID.uuid4(),
        title: "sample-title",
        slug: "sample-slug-#{UUID.uuid4()}",
        apparatusId: nil,
        description: nil,
        instrumentId: nil
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

      archive_metadata = fn number ->
        %{
          handler_name: "athlete.position_projection",
          event_number: number,
          event_id: UUID.uuid4(),
          stream_id: "position-#{event.id}",
          stream_version: number,
          correlation_id: nil,
          causation_id: nil,
          created_at: DateTime.utc_now(),
          application: Sportipedia.Catalog,
          state: nil
        }
      end

      # The position leaves the catalog once; the same fact arriving again has
      # no row to remove and must not fail the projection.
      assert :ok = PositionProjector.handle(event, archive_metadata.(2))
      assert :ok = PositionProjector.handle(event, archive_metadata.(3))

      assert Repo.get(PositionReadModel, event.id) == nil
    end
  end
end
