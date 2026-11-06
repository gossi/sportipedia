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

      # `position-archived` is a complete delete fact: after it, the position has
      # no state at all. There is no archived flag and no archived aggregate
      # state, and nothing in the model offers an unarchive that would need it.
      assert PositionAggregate.apply(%PositionAggregate{id: event.id}, event) == nil
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

      # A delete fact removes the row: the position is gone from the read model,
      # while the events stay in the store. There is no unarchive to undo it.
      assert Repo.get(PositionReadModel, event.id) == nil
    end

    test "replaying PositionArchived over an already deleted row is a no-op" do
      event = %PositionArchived{id: UUID.uuid4()}

      # The row is not there: an absent row is a no-op, which is what makes the
      # delete clause idempotent under replay.
      assert :ok = PositionProjector.handle(event, archive_metadata(event, 1))

      # The very same event, projected a second time, changes nothing and errors
      # nowhere.
      assert :ok = PositionProjector.handle(event, archive_metadata(event, 2))

      assert Repo.get(PositionReadModel, event.id) == nil
    end

    test "PositionArchived does not touch another position's row" do
      cataloged = %PositionCataloged{id: UUID.uuid4(), title: "Handstand", slug: "handstand"}
      assert :ok = PositionProjector.handle(cataloged, archive_metadata(cataloged, 1))

      archived = %PositionArchived{id: UUID.uuid4()}
      assert :ok = PositionProjector.handle(archived, archive_metadata(archived, 2))

      assert %PositionReadModel{title: "Handstand"} = Repo.get(PositionReadModel, cataloged.id)
    end
  end

  defp archive_metadata(event, event_number) do
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
