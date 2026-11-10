defmodule Sportipedia.Catalog.Athlete.Position.Event.PositionCatalogedTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  alias Sportipedia.Catalog.Athlete.Position.PositionProjector
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusEdited
  alias Sportipedia.Catalog.Equipment.Instrument.Event.InstrumentEdited
  alias Sportipedia.TestSupport.Catalog.Athlete
  alias Sportipedia.TestSupport.Catalog.Athlete.PositionFixtures
  alias Sportipedia.TestSupport.Catalog.Equipment
  alias Sportipedia.TestSupport.Catalog.Equipment.InstrumentFixtures
  @moduletag :integration
  describe "Event" do
    test "creates PositionCataloged with required fields" do
      event =
        struct!(PositionCataloged, %{
          id: UUID.uuid5(:dns, "athlete:position:unicycle-riding"),
          title: "Riding",
          slug: "riding",
          apparatusId: UUID.uuid4(),
          description: "Riding on a unicycle",
          instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle")
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
          id: UUID.uuid5(:dns, "athlete:position:unicycle-riding"),
          title: "Riding",
          slug: "riding",
          apparatusId: UUID.uuid4(),
          description: "Riding on a unicycle",
          instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle")
        })

      assert {:ok, _json} = Jason.encode(event)
    end
  end

  describe "Aggregate" do
    test "applies position-cataloged to aggregate state" do
      event = %PositionCataloged{
        id: UUID.uuid5(:dns, "athlete:position:unicycle-riding"),
        title: "Riding",
        slug: "riding",
        apparatusId: UUID.uuid4(),
        description: "Riding on a unicycle",
        instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle")
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
        id: UUID.uuid5(:dns, "athlete:position:unicycle-riding"),
        title: "Riding",
        slug: "riding",
        apparatusId: UUID.uuid4(),
        description: "Riding on a unicycle",
        instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle")
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

    test "re-derives the lookup slug of every position bound to a renamed apparatus" do
      Athlete.new_positions([
        PositionFixtures.gymnastics_straight_arm_support(),
        PositionFixtures.gymnastics_long_hang()
      ])

      event = %ApparatusEdited{
        id: UUID.uuid5(:dns, "equipment:apparatus:horizontal-bar"),
        title: "High Bar",
        slug: "high-bar"
      }

      assert :ok =
               PositionProjector.handle(event, projection_metadata(event, "equipment/apparatus/"))

      support = Repo.get(PositionReadModel, PositionFixtures.gymnastics_straight_arm_support().id)
      hang = Repo.get(PositionReadModel, PositionFixtures.gymnastics_long_hang().id)

      assert support.lookup_slug == "high-bar/straight-arm-support"
      assert hang.lookup_slug == "high-bar/long-hang"
      # The rename moves the namespace, never the position's own raw slug.
      assert support.slug == "straight-arm-support"
      assert hang.slug == "long-hang"
    end

    test "leaves the positions bound to other equipment alone when an apparatus is renamed" do
      Equipment.new_instrument(InstrumentFixtures.unicycle())

      Athlete.new_positions([
        PositionFixtures.gymnastics_long_hang(),
        PositionFixtures.unicycle_riding()
      ])

      event = %ApparatusEdited{
        id: UUID.uuid5(:dns, "equipment:apparatus:horizontal-bar"),
        slug: "high-bar"
      }

      assert :ok =
               PositionProjector.handle(event, projection_metadata(event, "equipment/apparatus/"))

      riding = Repo.get(PositionReadModel, PositionFixtures.unicycle_riding().id)

      assert riding.lookup_slug == "unicycle/riding"
    end

    test "keeps the lookup slug of bound positions when the equipment edit carries no new slug" do
      Athlete.new_position(PositionFixtures.gymnastics_long_hang())

      event = %ApparatusEdited{
        id: UUID.uuid5(:dns, "equipment:apparatus:horizontal-bar"),
        title: "Horizontal Bar, renamed in title only"
      }

      assert :ok =
               PositionProjector.handle(event, projection_metadata(event, "equipment/apparatus/"))

      hang = Repo.get(PositionReadModel, PositionFixtures.gymnastics_long_hang().id)

      assert hang.lookup_slug == "horizontal-bar/long-hang"
      assert hang.title == "Long Hang"
    end

    test "re-derives the lookup slug of every position bound to a renamed instrument" do
      Athlete.new_positions([
        PositionFixtures.unicycle_riding(),
        PositionFixtures.unicycle_on_tire(),
        PositionFixtures.gymnastics_long_hang()
      ])

      event = %InstrumentEdited{
        id: UUID.uuid5(:dns, "equipment:instrument:unicycle"),
        title: "Unicycle",
        slug: "unicorne"
      }

      assert :ok =
               PositionProjector.handle(
                 event,
                 projection_metadata(event, "equipment/instrument/")
               )

      riding = Repo.get(PositionReadModel, PositionFixtures.unicycle_riding().id)
      on_tire = Repo.get(PositionReadModel, PositionFixtures.unicycle_on_tire().id)
      hang = Repo.get(PositionReadModel, PositionFixtures.gymnastics_long_hang().id)

      assert riding.lookup_slug == "unicorne/riding"
      assert on_tire.lookup_slug == "unicorne/on-tire"
      # A position bound to an apparatus does not live in this instrument's namespace.
      assert hang.lookup_slug == "horizontal-bar/long-hang"
    end

    test "keeps one row when the replay hands PositionCataloged the same event number" do
      event = %PositionCataloged{
        id: UUID.uuid5(:dns, "athlete:position:unicycle-seat-in-front"),
        title: "Seat in-front",
        slug: "seat-in-front"
      }

      metadata = projection_metadata(event)

      assert :ok = PositionProjector.handle(event, metadata)
      assert :ok = PositionProjector.handle(event, metadata)

      assert Repo.aggregate(PositionReadModel, :count) == 1
    end

    test "follows an apparatus renamed through its own catalog, without any position command" do
      {:ok, apparatus} =
        Apparatus.catalog_apparatus(%{title: "Starting Blocks", slug: "starting-blocks"})

      {:ok, position} =
        Position.catalog_position(%{
          title: "Starting Block Position",
          slug: "take",
          apparatusId: apparatus.id
        })

      assert position.lookup_slug == "starting-blocks/take"

      {:ok, _renamed} = Apparatus.edit_apparatus(%{id: apparatus.id, slug: "starting-blocks-v2"})

      # The position projection subscribes to the equipment fact: the row moved
      # under the apparatus' new slug, and no position command was needed.
      assert %PositionReadModel{lookup_slug: moved, slug: "take"} =
               Repo.get(PositionReadModel, position.id)

      assert moved == "starting-blocks-v2/take"

      # The old path half of the QA scenario: the superseded canonical path
      # stops answering — the rename leaves nothing behind that `read-position`
      # would return.
      assert {:error, :not_found} = Position.read_position("starting-blocks/take")
    end
  end

  # The position projector reads the handler name and the event number from its
  # metadata; the stream it names belongs to the aggregate that published the
  # fact — the equipment for a rename, the position itself for its own events.
  defp projection_metadata(event, stream_prefix \\ "athlete/position/", event_number \\ 1) do
    %{
      handler_name: "athlete.position_projection",
      event_number: event_number,
      event_id: UUID.uuid4(),
      stream_id: stream_prefix <> event.id,
      stream_version: event_number,
      correlation_id: nil,
      causation_id: nil,
      created_at: DateTime.utc_now(),
      application: Sportipedia.Catalog,
      state: nil
    }
  end
end
