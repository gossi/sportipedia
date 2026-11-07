defmodule Sportipedia.Catalog.Athlete.Position.Operation.CatalogPositionTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Command.CatalogPosition
  alias Sportipedia.Catalog.Athlete.Position.Command.CatalogPositionHandler
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.Policy
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Instrument
  @moduletag :integration
  describe "Command" do
    test "requires id" do
      assert_raise ArgumentError, fn ->
        struct!(CatalogPosition, %{})
      end
    end

    test "validates presence of title" do
      cmd = %CatalogPosition{
        id: UUID.uuid4(),
        slug: "sample-slug",
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4(),
        title: nil
      }

      assert {:error, _errors} = Vex.validate(cmd)
    end

    test "validates presence of slug" do
      cmd = %CatalogPosition{
        id: UUID.uuid4(),
        title: "sample-title",
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4(),
        slug: nil
      }

      assert {:error, _errors} = Vex.validate(cmd)
    end

    test "rejects a slug that is already in the catalog" do
      slug = "guard-position-#{UUID.uuid4()}"
      assert {:ok, _position} = Position.catalog_position(%{title: "Guard Position", slug: slug})

      cmd = %CatalogPosition{id: UUID.uuid4(), title: "Another Position", slug: slug}

      assert {:error, [{:error, :slug, :by, :slug_exists}]} = Vex.validate(cmd)
    end

    test "rejects a slug that is not lower-case, or holds a non-slug character, or starts with a dash" do
      for slug <- ["Ready-STANCE", "ready stance", "-ready", "ready_stance"] do
        cmd = %CatalogPosition{id: UUID.uuid4(), title: "Ready Stance", slug: slug}

        assert {:error, [{:error, :slug, :by, :invalid_slug}]} = Vex.validate(cmd)
      end
    end

    test "accepts a canonical slug of lower-case letters, digits and dashes" do
      cmd = %CatalogPosition{
        id: UUID.uuid4(),
        title: "Lunge 2",
        slug: "lunge-2-position"
      }

      assert {:ok, ^cmd} = Vex.validate(cmd)
    end

    test "rejects a position that references both an apparatus and an instrument" do
      assert {:ok, apparatus} =
               Apparatus.catalog_apparatus(%{
                 title: "Starting Blocks",
                 slug: "starting-blocks-#{UUID.uuid4()}"
               })

      assert {:ok, instrument} =
               Instrument.catalog_instrument(%{
                 title: "Jump Rope",
                 slug: "jump-rope-#{UUID.uuid4()}"
               })

      cmd = %CatalogPosition{
        id: UUID.uuid4(),
        title: "Blocked Position",
        slug: "blocked-position-#{UUID.uuid4()}",
        apparatusId: apparatus.id,
        instrumentId: instrument.id
      }

      assert {:error, errors} = Vex.validate(cmd)

      assert {:error, :apparatusId, :by, :only_one_equipment_allowed} in errors
      assert {:error, :instrumentId, :by, :only_one_equipment_allowed} in errors
    end

    test "accepts a position referencing one existing piece of equipment" do
      assert {:ok, apparatus} =
               Apparatus.catalog_apparatus(%{
                 title: "Balance Beam",
                 slug: "balance-beam-#{UUID.uuid4()}"
               })

      assert {:ok, instrument} =
               Instrument.catalog_instrument(%{
                 title: "Dumbbell",
                 slug: "dumbbell-#{UUID.uuid4()}"
               })

      cmd_with_apparatus = %CatalogPosition{
        id: UUID.uuid4(),
        title: "Handstand",
        slug: "handstand-#{UUID.uuid4()}",
        apparatusId: apparatus.id
      }

      assert {:ok, ^cmd_with_apparatus} = Vex.validate(cmd_with_apparatus)

      cmd_with_instrument = %CatalogPosition{
        id: UUID.uuid4(),
        title: "Grip Position",
        slug: "grip-position-#{UUID.uuid4()}",
        instrumentId: instrument.id
      }

      assert {:ok, ^cmd_with_instrument} = Vex.validate(cmd_with_instrument)
    end

    test "rejects a position referencing equipment that does not exist" do
      assert {:ok, apparatus} =
               Apparatus.catalog_apparatus(%{
                 title: "Parallel Bars",
                 slug: "parallel-bars-#{UUID.uuid4()}"
               })

      unknown_apparatus = %CatalogPosition{
        id: UUID.uuid4(),
        title: "Unknown Apparatus Position",
        slug: "unknown-apparatus-#{UUID.uuid4()}",
        apparatusId: UUID.uuid4()
      }

      assert {:error, [{:error, :apparatusId, :by, :equipment_not_found}]} =
               Vex.validate(unknown_apparatus)

      unknown_instrument = %CatalogPosition{
        id: UUID.uuid4(),
        title: "Unknown Instrument Position",
        slug: "unknown-instrument-#{UUID.uuid4()}",
        instrumentId: UUID.uuid4()
      }

      assert {:error, [{:error, :instrumentId, :by, :equipment_not_found}]} =
               Vex.validate(unknown_instrument)

      # A legal reference is an id, never a slug — and it points at the kind the
      # field names: an existing apparatus is no instrument.
      apparatus_id_as_instrument = %CatalogPosition{
        id: UUID.uuid4(),
        title: "Crossed Reference Position",
        slug: "crossed-reference-#{UUID.uuid4()}",
        instrumentId: apparatus.id
      }

      assert {:error, [{:error, :instrumentId, :by, :equipment_not_found}]} =
               Vex.validate(apparatus_id_as_instrument)
    end

    test "rejects a malformed equipment reference without asking the database" do
      cmd = %CatalogPosition{
        id: UUID.uuid4(),
        title: "Malformed Reference Position",
        slug: "malformed-reference-#{UUID.uuid4()}",
        apparatusId: "not-a-uuid"
      }

      assert {:error, [{:error, :apparatusId, :by, :equipment_not_found}]} = Vex.validate(cmd)
    end
  end

  describe "Command Handler" do
    test "handles CatalogPosition command and returns PositionCataloged event" do
      cmd = %CatalogPosition{
        id: UUID.uuid4(),
        title: "sample-title",
        slug: "sample-slug",
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4()
      }

      events = CatalogPositionHandler.handle(%PositionAggregate{}, cmd)

      assert %PositionCataloged{} = events
    end

    test "cataloging a position emits its data with the slug carried through unchanged" do
      apparatus_id = UUID.uuid4()
      instrument_id = UUID.uuid4()

      cmd = %CatalogPosition{
        id: UUID.uuid4(),
        title: "Ready Stance",
        slug: "ready-stance",
        description: "Athletic stance with knees slightly bent",
        apparatusId: apparatus_id,
        instrumentId: instrument_id
      }

      event = CatalogPositionHandler.handle(%PositionAggregate{}, cmd)

      assert %PositionCataloged{} = event
      assert event.id == cmd.id
      assert event.title == "Ready Stance"
      assert event.slug == "ready-stance"
      assert event.description == "Athletic stance with knees slightly bent"
      assert event.apparatusId == apparatus_id
      assert event.instrumentId == instrument_id
    end
  end

  describe "Policy" do
    test "denies or allows guests for catalog_position" do
      assert Policy.authorize(:catalog_position, nil, %{}) == :error
    end

    test "allows users for catalog_position" do
      assert Policy.authorize(:catalog_position, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
    end
  end

  describe "Public API" do
    test "catalog_position succeeds" do
      assert {:ok, read_model} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "sample-slug-#{UUID.uuid4()}"
               })

      assert read_model.id != nil
    end

    test "catalog_position with an apparatus reference returns the projected position" do
      assert {:ok, apparatus} =
               Apparatus.catalog_apparatus(%{
                 title: "Rings",
                 slug: "rings-#{UUID.uuid4()}"
               })

      slug = "ring-hang-#{UUID.uuid4()}"

      assert {:ok, read_model} =
               Position.catalog_position(%{
                 title: "Ring Hang",
                 slug: slug,
                 description: "Hanging from the rings with arms fully extended",
                 apparatusId: apparatus.id
               })

      assert read_model.title == "Ring Hang"
      assert read_model.slug == slug
      assert read_model.apparatusId == apparatus.id
      assert read_model.instrumentId == nil
      assert read_model.description == "Hanging from the rings with arms fully extended"
    end

    test "catalog_position returns validation errors" do
      assert {:error, {:validation_failure, _errors}} = Position.catalog_position(%{})
    end
  end
end
