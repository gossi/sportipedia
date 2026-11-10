defmodule Sportipedia.Catalog.Athlete.Position.Event.PositionEditedTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionEdited
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  alias Sportipedia.Catalog.Athlete.Position.PositionProjector
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.TestSupport.Catalog.Athlete
  alias Sportipedia.TestSupport.Catalog.Athlete.PositionFixtures
  alias Sportipedia.TestSupport.Catalog.Equipment
  alias Sportipedia.TestSupport.Catalog.Equipment.InstrumentFixtures
  @moduletag :integration
  describe "Event" do
    test "creates PositionEdited with required fields" do
      event =
        struct!(PositionEdited, %{
          id: UUID.uuid5(:dns, "athlete:position:unicycle-riding"),
          apparatusId: UUID.uuid4(),
          description: "Riding on a unicycle",
          instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle"),
          slug: "riding",
          title: "Riding"
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
          id: UUID.uuid5(:dns, "athlete:position:unicycle-riding"),
          apparatusId: UUID.uuid4(),
          description: "Riding on a unicycle",
          instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle"),
          slug: "riding",
          title: "Riding"
        })

      assert {:ok, _json} = Jason.encode(event)
    end
  end

  describe "Aggregate" do
    test "applies position-edited to aggregate state" do
      event = %PositionEdited{
        id: UUID.uuid5(:dns, "athlete:position:unicycle-riding"),
        apparatusId: UUID.uuid4(),
        description: "Riding on a unicycle",
        instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle"),
        slug: "riding",
        title: "Riding"
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

      event = %PositionEdited{
        id: create_event.id,
        apparatusId: UUID.uuid4(),
        description: "Riding on a unicycle",
        instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle"),
        slug: "riding",
        title: "Riding"
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

    test "re-derives the canonical path when the edit renames the raw slug" do
      {:ok, _unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      {:ok, position} = Athlete.new_position(PositionFixtures.unicycle_riding())

      event = %PositionEdited{id: position.id, slug: "balancing-on-the-seat"}

      assert :ok = PositionProjector.handle(event, metadata(event, 2))

      edited = Repo.get(PositionReadModel, position.id)
      assert edited.slug == "balancing-on-the-seat"
      # The patch carried no reference, so the namespace comes from the stored
      # binding — and the stored binding is left exactly where it was.
      assert edited.lookup_slug == "unicycle/balancing-on-the-seat"
      assert edited.instrumentId == position.instrumentId
    end

    test "re-derives the canonical path when the edit moves the equipment binding" do
      {:ok, _unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      {:ok, skateboard} = Equipment.new_instrument(InstrumentFixtures.skateboard())
      {:ok, position} = Athlete.new_position(PositionFixtures.unicycle_riding())

      event = %PositionEdited{id: position.id, instrumentId: skateboard.id}

      assert :ok = PositionProjector.handle(event, metadata(event, 2))

      edited = Repo.get(PositionReadModel, position.id)
      assert edited.instrumentId == skateboard.id
      # The raw slug did not move, only its namespace.
      assert edited.slug == "riding"
      assert edited.lookup_slug == "skateboard/riding"
    end

    test "leaves the canonical path where it is for an edit that moved neither slug nor binding" do
      # No equipment row is seeded here on purpose: a patch that moved neither the
      # raw slug nor the binding must not ask the equipment for its slug at all.
      # Re-deriving on every patch would rewrite the canonical path from a read
      # that answers nothing, so this case is the proof the clause leaves it alone.
      {:ok, position} = Athlete.new_position(PositionFixtures.gymnastics_straight_arm_support())

      event = %PositionEdited{id: position.id, title: "Straight Arm Support"}

      assert :ok = PositionProjector.handle(event, metadata(event, 2))

      edited = Repo.get(PositionReadModel, position.id)
      assert edited.title == "Straight Arm Support"
      assert edited.slug == "straight-arm-support"
      assert edited.lookup_slug == "horizontal-bar/straight-arm-support"
      assert edited.apparatusId == position.apparatusId
    end

    test "keeps the row of a position that is not in the catalog untouched" do
      event = %PositionEdited{
        id: UUID.uuid5(:dns, "athlete:position:not-in-the-catalog"),
        title: "Never Cataloged"
      }

      assert :ok = PositionProjector.handle(event, metadata(event, 1))

      assert Repo.get(PositionReadModel, event.id) == nil
    end

    test "projecting the same edit twice leaves the canonical path single-valued" do
      {:ok, _unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      {:ok, position} = Athlete.new_position(PositionFixtures.unicycle_riding())

      event = %PositionEdited{id: position.id, slug: "riding-a-unicycle"}

      assert :ok = PositionProjector.handle(event, metadata(event, 2))
      assert :ok = PositionProjector.handle(event, metadata(event, 3))

      edited = Repo.get(PositionReadModel, position.id)
      assert edited.lookup_slug == "unicycle/riding-a-unicycle"

      siblings =
        Repo.all(
          from(p in PositionReadModel, where: p.lookup_slug == "unicycle/riding-a-unicycle")
        )

      assert length(siblings) == 1
    end
  end

  # A projection is addressed by its place in the stream: `handler_name` is the
  # projector's `name:` option and `event_number` is unique per event.
  defp metadata(event, event_number) do
    %{
      handler_name: "athlete.position_projection",
      event_number: event_number,
      event_id: UUID.uuid4(),
      stream_id: "athlete/position/#{event.id}",
      stream_version: event_number,
      correlation_id: nil,
      causation_id: nil,
      created_at: DateTime.utc_now(),
      application: Sportipedia.Catalog,
      state: nil
    }
  end
end
