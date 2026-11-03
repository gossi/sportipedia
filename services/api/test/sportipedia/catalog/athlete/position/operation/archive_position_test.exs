defmodule Sportipedia.Catalog.Athlete.Position.Operation.ArchivePositionTest do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Command.ArchivePosition
  alias Sportipedia.Catalog.Athlete.Position.Command.ArchivePositionHandler
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionArchived
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.Policy
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  alias Sportipedia.Catalog.Athlete.Position.PositionProjector
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  @moduletag :integration

  describe "PositionArchived event" do
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

  describe "ArchivePositionHandler" do
    test "handles ArchivePosition command and returns PositionArchived event" do
      cmd = %ArchivePosition{id: UUID.uuid4()}

      events = ArchivePositionHandler.handle(%PositionAggregate{}, cmd)

      assert %PositionArchived{} = events
    end
  end

  describe "PositionAggregate" do
    test "applies position-archived to aggregate state" do
      event = %PositionArchived{id: UUID.uuid4()}

      result = PositionAggregate.apply(%PositionAggregate{id: event.id}, event)

      assert result.id == event.id
    end
  end

  describe "ArchivePosition command" do
    test "requires id" do
      assert_raise ArgumentError, fn ->
        struct!(ArchivePosition, %{})
      end
    end

    test "id cannot be nil" do
      cmd = %ArchivePosition{id: nil}

      assert_raise ArgumentError, fn ->
        Vex.validate(cmd)
      end
    end
  end

  describe "Policy - archive_position" do
    test "denies or allows guests for archive_position" do
      assert Policy.authorize(:archive_position, nil, %{}) == :error
    end

    test "allows users for archive_position" do
      assert Policy.authorize(:archive_position, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
    end
  end

  describe "PositionProjector - PositionArchived" do
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

      assert Repo.get(PositionReadModel, event.id) != nil
    end
  end

  describe "Public API - archive_position" do
    test "archive_position succeeds" do
      assert {:ok, created} =
               Position.catalog_position(%{title: "sample-title", slug: "sample-slug"})

      assert :ok = Position.archive_position(created.id)
    end

    test "archive_position fails for an unknown position" do
      assert {:error, _} = Position.archive_position(UUID.uuid4())
    end
  end
end
