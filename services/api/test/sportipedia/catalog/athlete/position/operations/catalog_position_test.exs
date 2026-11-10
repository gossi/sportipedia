defmodule Sportipedia.Catalog.Athlete.Position.Operation.CatalogPositionTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Command.CatalogPosition
  alias Sportipedia.Catalog.Athlete.Position.Command.CatalogPositionHandler
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.Policy
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.TestSupport.Catalog.Athlete
  alias Sportipedia.TestSupport.Catalog.Athlete.PositionFixtures
  alias Sportipedia.TestSupport.Catalog.Equipment
  alias Sportipedia.TestSupport.Catalog.Equipment.ApparatusFixtures
  alias Sportipedia.TestSupport.Catalog.Equipment.InstrumentFixtures
  @moduletag :integration
  describe "Command" do
    test "requires id" do
      assert_raise ArgumentError, fn ->
        struct!(CatalogPosition, %{})
      end
    end

    test "validates presence of title" do
      cmd = %CatalogPosition{
        id: UUID.uuid5(:dns, "athlete:position:unicycle-riding"),
        slug: "riding",
        apparatusId: UUID.uuid4(),
        description: "Riding on a unicycle",
        instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle"),
        title: nil
      }

      assert {:error, _errors} = Vex.validate(cmd)
    end

    test "validates presence of slug" do
      cmd = %CatalogPosition{
        id: UUID.uuid5(:dns, "athlete:position:unicycle-riding"),
        title: "Riding",
        apparatusId: UUID.uuid4(),
        description: "Riding on a unicycle",
        instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle"),
        slug: nil
      }

      assert {:error, _errors} = Vex.validate(cmd)
    end

    test "rejects a raw slug that already names a position under the same equipment" do
      Equipment.new_instrument(InstrumentFixtures.unicycle())
      Athlete.new_position(PositionFixtures.unicycle_riding())

      cmd = %CatalogPosition{
        id: UUID.uuid4(),
        title: "Seat in-front",
        slug: "riding",
        instrumentId: InstrumentFixtures.unicycle().id
      }

      assert Enum.any?(Vex.errors(cmd), &match?({:error, :slug, _, :slug_exists}, &1))
    end
  end

  describe "Command Handler" do
    test "handles CatalogPosition command and returns PositionCataloged event" do
      cmd = %CatalogPosition{
        id: UUID.uuid5(:dns, "athlete:position:unicycle-riding"),
        title: "Riding",
        slug: "riding",
        apparatusId: UUID.uuid4(),
        description: "Riding on a unicycle",
        instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle")
      }

      events = CatalogPositionHandler.handle(%PositionAggregate{}, cmd)

      assert %PositionCataloged{} = events
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
      assert {:ok, read_model} = Position.catalog_position(%{title: "Riding", slug: "riding"})

      assert read_model.id != nil
    end

    test "catalog_position returns validation errors" do
      assert {:error, {:validation_failure, _errors}} = Position.catalog_position(%{})
    end

    test "rejects a slug that is not in canonical form, before dispatch" do
      # The canonical form — lower-case letters, digits, dashes, no leading
      # dash — is a boundary rule: a raw slug that deviates never reaches a
      # fact or a row, so the write side stores one spelling per slug by the
      # gate itself, and the lookup paths stay disjoint.
      assert {:error, {:validation_failure, failures}} =
               Position.catalog_position(%{title: "Seat in-front", slug: "Seat-IN-Front"})

      assert failures == %{slug: [:invalid_slug]}

      assert Repo.aggregate(PositionReadModel, :count) == 0
    end

    test "rejects a position that names both an apparatus and an instrument" do
      Equipment.new_apparatus(ApparatusFixtures.parallel_bars())
      Equipment.new_instrument(InstrumentFixtures.unicycle())

      assert {:error, {:validation_failure, failures}} =
               Position.catalog_position(%{
                 title: "Straight-arm support",
                 slug: "straight-arm-support",
                 apparatusId: ApparatusFixtures.parallel_bars().id,
                 instrumentId: InstrumentFixtures.unicycle().id
               })

      assert failures == %{
               apparatusId: [:too_many_equipment],
               instrumentId: [:too_many_equipment]
             }

      # Rejected before dispatch: no fact, so no row in the catalog.
      assert Repo.aggregate(PositionReadModel, :count) == 0
    end

    test "rejects an equipment reference that cannot name an equipment" do
      assert {:error, {:validation_failure, failures}} =
               Position.catalog_position(%{
                 title: "Starting Block Position",
                 slug: "take",
                 apparatusId: "starting-blocks"
               })

      # The UUID guard answers the verdict, so the reference never reaches a read
      # model that could not hold it — and the atom is not `:not_found`, which
      # would turn this 422 into a 404 for a position nobody addressed.
      assert failures == %{apparatusId: [:equipment_not_found]}

      assert Repo.aggregate(PositionReadModel, :count) == 0
    end

    test "catalogs an unbound position under its own bare slug" do
      assert {:ok, position} =
               Position.catalog_position(%{
                 title: "Ready Stance",
                 slug: "ready-stance",
                 description: "Athletic stance with knees slightly bent"
               })

      # No equipment, so no namespace: the raw slug is the whole canonical path.
      assert position.lookup_slug == "ready-stance"
      assert position.apparatusId == nil
      assert position.instrumentId == nil
    end

    test "catalogs a bound position under the equipment's namespace" do
      Equipment.new_apparatus(ApparatusFixtures.parallel_bars())

      assert {:ok, position} =
               Position.catalog_position(%{
                 title: "Starting Block Position",
                 slug: "take",
                 apparatusId: ApparatusFixtures.parallel_bars().id
               })

      assert position.slug == "take"
      assert position.lookup_slug == "parallel-bars/take"
      assert position.apparatusId == ApparatusFixtures.parallel_bars().id
    end

    test "catalogs the same raw slug under different equipment" do
      Equipment.new_apparatus(ApparatusFixtures.parallel_bars())
      Equipment.new_apparatus(ApparatusFixtures.balance_beam())

      assert {:ok, on_bars} =
               Position.catalog_position(%{
                 title: "Take",
                 slug: "take",
                 apparatusId: ApparatusFixtures.parallel_bars().id
               })

      assert {:ok, on_beam} =
               Position.catalog_position(%{
                 title: "Take",
                 slug: "take",
                 apparatusId: ApparatusFixtures.balance_beam().id
               })

      # Two namespaces, two canonical paths: each position answers its own.
      assert on_bars.lookup_slug == "parallel-bars/take"
      assert on_beam.lookup_slug == "balance-beam/take"
    end

    test "rejects a slug already taken inside the referenced equipment and emits no fact" do
      {:ok, _unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())

      {:ok, riding} =
        Position.catalog_position(%{
          title: "Riding",
          slug: "riding",
          instrumentId: InstrumentFixtures.unicycle().id
        })

      assert {:error, {:validation_failure, failures}} =
               Position.catalog_position(%{
                 title: "Standing on the tire",
                 slug: "riding",
                 instrumentId: InstrumentFixtures.unicycle().id
               })

      assert failures == %{slug: [:slug_exists]}

      assert Repo.all(from p in PositionReadModel, select: p.id) == [riding.id]

      # Fact level, the archive test's stream idiom: the rejected duplicate
      # emitted no event — the one position stream this test names still holds
      # exactly the fact of its own cataloging. (The rejected command's own
      # stream is unnameable from outside: `catalog_position/1` mints the id
      # internally, per the slice's own ruling, so no new fact can be looked up
      # by an id the test never had.)
      stream =
        Commanded.EventStore.stream_forward(
          Sportipedia.Catalog,
          "athlete/position/" <> riding.id
        )

      id = riding.id

      assert [%PositionCataloged{id: ^id}] = Enum.map(stream, & &1.data)
    end

    test "rejects an unbound position whose bare slug an unbound position already holds" do
      Athlete.new_position(PositionFixtures.ready_stance())

      # The create path carries no reference and addresses no stored position, so
      # its effective namespace is the unbound one — and the bare slug taken there
      # is rejected before dispatch, not by the unique index behind it.
      assert {:error, {:validation_failure, failures}} =
               Position.catalog_position(%{
                 title: "Ready Stance, again",
                 slug: "ready-stance"
               })

      assert failures == %{slug: [:slug_exists]}

      assert Repo.all(from p in PositionReadModel, select: p.id) == [
               PositionFixtures.ready_stance().id
             ]
    end

    test "rejects a raw slug that would claim another namespace's canonical path" do
      Equipment.new_apparatus(ApparatusFixtures.parallel_bars())

      {:ok, bound} =
        Position.catalog_position(%{
          title: "Take",
          slug: "take",
          apparatusId: ApparatusFixtures.parallel_bars().id
        })

      assert bound.lookup_slug == "parallel-bars/take"

      # The disjointness argument of `unique-slug-by-equipment` — a bound and an
      # unbound position can never derive the same lookup slug, because the
      # namespaced form carries a `/` — only holds by construction if raw slugs
      # cannot carry `/`. A raw slug that looks like a path is malformed at the
      # boundary: it is rejected as `:invalid_slug` before dispatch, never
      # accepted into the projection the `lookup_slug` index then refuses.
      assert {:error, {:validation_failure, failures}} =
               Position.catalog_position(%{
                 title: "Take, unbound",
                 slug: "parallel-bars/take"
               })

      assert failures == %{slug: [:invalid_slug]}

      assert Repo.all(from p in PositionReadModel, select: p.id) == [bound.id]
    end
  end
end
