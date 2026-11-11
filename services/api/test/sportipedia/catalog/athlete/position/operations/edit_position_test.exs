defmodule Sportipedia.Catalog.Athlete.Position.Operation.EditPositionTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Command.EditPosition
  alias Sportipedia.Catalog.Athlete.Position.Command.EditPositionHandler
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionEdited
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
        struct!(EditPosition, %{})
      end
    end

    test "id cannot be nil" do
      cmd = %EditPosition{
        apparatusId: UUID.uuid4(),
        description: "Riding on a unicycle",
        instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle"),
        slug: "riding",
        title: "Riding",
        id: nil
      }

      # Rejected, not raised: the existence check used to hand the nil to
      # `Repo.get/2`, which raises, and the command never got to answer.
      # `allow_blank` on the `validates` line keeps the lookup off an absent
      # address, so `presence` is the only rule that speaks for the id.
      assert [:presence] ==
               cmd
               |> Vex.errors()
               |> Enum.flat_map(fn {_error, field, rule, _message} ->
                 if field == :id, do: [rule], else: []
               end)
    end
  end

  describe "Command Handler" do
    test "handles EditPosition command and returns PositionEdited event" do
      cmd = %EditPosition{
        id: UUID.uuid5(:dns, "athlete:position:unicycle-riding"),
        apparatusId: UUID.uuid4(),
        description: "Riding on a unicycle",
        instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle"),
        slug: "riding",
        title: "Riding"
      }

      events = EditPositionHandler.handle(%PositionAggregate{}, cmd)

      assert %PositionEdited{} = events
    end

    test "edits a position by carrying the fields the patch supplied" do
      apparatus_id = UUID.uuid4()

      cmd = %EditPosition{
        id: UUID.uuid5(:dns, "athlete:position:gymnastics-straight-arm-support"),
        title: "Straight Arm Support",
        description: "Arms straight, shoulders over the bar",
        apparatusId: apparatus_id
      }

      event = EditPositionHandler.handle(%PositionAggregate{id: cmd.id}, cmd)

      assert event.id == cmd.id
      assert event.title == "Straight Arm Support"
      assert event.description == "Arms straight, shoulders over the bar"
      assert event.apparatusId == apparatus_id
    end

    test "emits the raw slug in canonical lower-case form" do
      cmd = %EditPosition{
        id: UUID.uuid5(:dns, "athlete:position:gymnastics-long-hang"),
        slug: "Long-Hang"
      }

      event = EditPositionHandler.handle(%PositionAggregate{id: cmd.id}, cmd)

      assert event.slug == "long-hang"
    end

    test "leaves a field the patch does not carry out of the fact" do
      # A reference the patch omits is left alone: `PositionEdited.get_changes/1`
      # is what the read model applies, so a field that stays nil never reaches
      # the stored row.
      cmd = %EditPosition{
        id: UUID.uuid5(:dns, "athlete:position:unicycle-on-tire"),
        title: "On the Tire"
      }

      event = EditPositionHandler.handle(%PositionAggregate{id: cmd.id}, cmd)

      assert PositionEdited.get_changes(event) == %{title: "On the Tire"}
    end
  end

  describe "Policy" do
    test "denies or allows guests for edit_position" do
      assert Policy.authorize(:edit_position, nil, %{}) == :error
    end

    test "allows users for edit_position" do
      assert Policy.authorize(:edit_position, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
    end
  end

  describe "Public API" do
    test "edit_position succeeds" do
      assert {:ok, created} = Position.catalog_position(%{title: "Riding", slug: "riding"})

      assert {:ok, read_model} = Position.edit_position(%{id: created.id})

      assert read_model.id == created.id
    end

    test "editing a position that is not in the catalog answers not found" do
      # The patch never names a slug or a reference, so the existence rule is the
      # only rule that speaks — and `:not_found` is its answer, never a validation
      # failure for a field the caller did send.
      assert {:error, :not_found} =
               Position.edit_position(%{id: UUID.uuid4(), title: "Handstand"})
    end

    test "editing a position that left the catalog answers not found" do
      {:ok, _unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      position = catalog_position_fixture(PositionFixtures.unicycle_on_tire())

      assert :ok = Position.archive_position(position.id)

      assert {:error, :not_found} =
               Position.edit_position(%{id: position.id, title: "On The Tire"})
    end

    test "re-supplying the position's own slug is accepted and keeps the canonical path" do
      # The owner-tolerance case of `unique-slug-by-equipment`: the row the edit
      # addresses already owns the value, so the invariant holds.
      {:ok, _unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      position = catalog_position_fixture(PositionFixtures.unicycle_riding())

      assert {:ok, edited} =
               Position.edit_position(%{
                 id: position.id,
                 title: "Balancing",
                 slug: "riding"
               })

      assert edited.title == "Balancing"
      assert edited.raw_slug == "riding"
      assert edited.slug == "unicycle/riding"
    end

    test "an edit that takes a slug another position holds in the same equipment is rejected" do
      {:ok, unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      riding = catalog_position_fixture(PositionFixtures.unicycle_riding())
      seat_in_front = catalog_position_fixture(PositionFixtures.unicycle_seat_in_front())

      # A reference the patch carries wins: the rule resolves the effective
      # namespace from it, and `riding` is taken inside `unicycle` by another row.
      assert {:error, {:validation_failure, failures}} =
               Position.edit_position(%{
                 id: seat_in_front.id,
                 slug: "riding",
                 instrumentId: unicycle.id
               })

      assert :slug_exists in failures[:slug]
      # The rejected patch leaves the catalog as it was.
      assert Repo.get(PositionReadModel, seat_in_front.id).raw_slug == "seat-in-front"
      assert Repo.get(PositionReadModel, riding.id).raw_slug == "riding"
    end

    test "an edit that omits the equipment reference is checked inside the stored namespace" do
      {:ok, _unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      riding = catalog_position_fixture(PositionFixtures.unicycle_riding())
      seat_in_front = catalog_position_fixture(PositionFixtures.unicycle_seat_in_front())

      # The patch carries no reference, so the stored binding decides the
      # namespace: `riding` is taken inside `unicycle` by another row. Answered as
      # a 422 on the field — never accepted into a projection that could not hold
      # the path.
      assert {:error, {:validation_failure, failures}} =
               Position.edit_position(%{id: seat_in_front.id, slug: "riding"})

      assert failures[:slug] == [:slug_exists]

      assert Repo.get(PositionReadModel, seat_in_front.id).raw_slug == "seat-in-front"
      assert Repo.get(PositionReadModel, riding.id).slug == "unicycle/riding"
    end

    test "an edit that omits the reference accepts a slug an unbound position already holds" do
      {:ok, _unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      Athlete.new_position(PositionFixtures.ready_stance())
      position = catalog_position_fixture(PositionFixtures.unicycle_riding())

      # The stored namespace, not the bare one, decides: `ready-stance` is taken
      # among the unbound positions, and this position lives under `unicycle`, so
      # the two paths never collide.
      assert {:ok, edited} = Position.edit_position(%{id: position.id, slug: "ready-stance"})

      assert edited.raw_slug == "ready-stance"
      assert edited.slug == "unicycle/ready-stance"
    end

    test "an edit that re-supplies its own slug with no reference in the patch is accepted" do
      {:ok, _unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      Athlete.new_position(PositionFixtures.ready_stance())
      position = catalog_position_fixture(PositionFixtures.unicycle_riding())

      assert {:ok, moved} = Position.edit_position(%{id: position.id, slug: "ready-stance"})
      assert moved.slug == "unicycle/ready-stance"

      # Now the raw slug `ready-stance` is held twice, once unbound and once under
      # `unicycle`. Re-supplying it without a reference finds the stored row — the
      # owner — so the edit passes through the fallback on owner tolerance.
      assert {:ok, again} =
               Position.edit_position(%{
                 id: position.id,
                 title: "Balancing",
                 slug: "ready-stance"
               })

      assert again.title == "Balancing"
      assert again.raw_slug == "ready-stance"
      assert again.slug == "unicycle/ready-stance"
    end

    test "an edit of an address that is not in the catalog stays not found" do
      Athlete.new_position(PositionFixtures.ready_stance())

      # The address is `position-exists`' verdict; the uniqueness rule's answer
      # never replaces it: ErrorClassifier reads the `:not_found` out of the
      # failures and answers the whole command with it.
      assert {:error, :not_found} =
               Position.edit_position(%{id: UUID.uuid4(), slug: "ready-stance"})

      assert Repo.get(PositionReadModel, PositionFixtures.ready_stance().id).slug ==
               "ready-stance"
    end

    test "an edit that supplies a non-canonical slug is rejected before dispatch" do
      {:ok, _unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      position = catalog_position_fixture(PositionFixtures.unicycle_riding())

      # The same boundary rule as `catalog-position` — and a patch may carry no
      # slug at all, so this pair skips nil (`allow_nil: true`): charset speaks
      # only for a slug the patch actually supplies. The non-canonical slug
      # never reaches a fact, and the stored path stays where it is.
      assert {:error, {:validation_failure, failures}} =
               Position.edit_position(%{id: position.id, slug: "On-Tire"})

      assert failures == %{slug: [:invalid_slug]}

      row = Repo.get(PositionReadModel, position.id)
      assert row.raw_slug == "riding"
      assert row.slug == "unicycle/riding"
    end

    test "an edit that omits the equipment reference leaves the binding and the path alone" do
      {:ok, _unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      position = catalog_position_fixture(PositionFixtures.unicycle_riding())

      assert {:ok, edited} = Position.edit_position(%{id: position.id, title: "Riding High"})

      assert edited.title == "Riding High"
      assert edited.instrumentId == position.instrumentId
      assert edited.raw_slug == "riding"
      assert edited.slug == "unicycle/riding"
    end

    test "an edit that re-supplies an equipment reference is checked like a new one" do
      {:ok, _unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      position = catalog_position_fixture(PositionFixtures.unicycle_riding())

      assert {:error, {:validation_failure, failures}} =
               Position.edit_position(%{id: position.id, apparatusId: UUID.uuid4()})

      assert :equipment_not_found in failures[:apparatusId]
    end

    test "an edit that carries both equipment references is rejected" do
      {:ok, _unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      {:ok, parallel_bars} = Equipment.new_apparatus(ApparatusFixtures.parallel_bars())
      position = catalog_position_fixture(PositionFixtures.unicycle_riding())

      assert {:error, {:validation_failure, failures}} =
               Position.edit_position(%{
                 id: position.id,
                 apparatusId: parallel_bars.id,
                 instrumentId: position.instrumentId
               })

      assert :too_many_equipment in failures[:apparatusId]
      assert :too_many_equipment in failures[:instrumentId]
    end

    test "an edit that moves the equipment binding re-derives the canonical path" do
      {:ok, _unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      {:ok, skateboard} = Equipment.new_instrument(InstrumentFixtures.skateboard())
      position = catalog_position_fixture(PositionFixtures.unicycle_riding())

      assert {:ok, edited} =
               Position.edit_position(%{id: position.id, instrumentId: skateboard.id})

      assert edited.instrumentId == skateboard.id
      assert edited.apparatusId == nil
      assert edited.raw_slug == "riding"
      assert edited.slug == "skateboard/riding"
    end

    test "an edit that only moves the equipment binding re-validates the stored slug in the patch's namespace" do
      {:ok, unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      catalog_position_fixture(PositionFixtures.unicycle_riding())

      # A second position holding the same raw slug in the bare namespace:
      # `riding` and `unicycle/riding` are disjoint paths, so this pairing is
      # legal — until a move says otherwise.
      assert {:ok, mover} = Position.catalog_position(%{title: "Riding Seat", slug: "riding"})

      assert mover.slug == "riding"

      # The patch carries a reference and no slug — but the stored raw slug
      # moves into `unicycle`'s namespace with it, and `riding` is taken there
      # by another position. The invariant is re-validated before dispatch:
      # the 422 names the reference the patch moved, never a projection the
      # unique index then refuses with a 500.
      assert {:error, {:validation_failure, failures}} =
               Position.edit_position(%{id: mover.id, instrumentId: unicycle.id})

      assert failures == %{instrumentId: [:slug_exists]}

      # The rejected patch leaves the row where it was: the bare path stands.
      row = Repo.get(PositionReadModel, mover.id)
      assert row.raw_slug == "riding"
      assert row.slug == "riding"
      assert row.instrumentId == nil
    end

    test "an edit that re-supplies its own equipment reference without a slug is accepted" do
      {:ok, unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      position = catalog_position_fixture(PositionFixtures.unicycle_riding())

      # The move-check's owner case: the row the namespace lookup finds is the
      # addressed position itself, so nothing collided — the patch changes
      # nothing and must not be rejected.
      assert {:ok, edited} =
               Position.edit_position(%{id: position.id, instrumentId: unicycle.id})

      assert edited.raw_slug == "riding"
      assert edited.slug == "unicycle/riding"
    end
  end

  # A position an edit can act on needs the aggregate, and only a command dispatch
  # builds it — so the fixture's own data goes through the port. `id` and the
  # derived `slug` are not inputs: the API makes the id and the projector
  # derives the path.
  defp catalog_position_fixture(%PositionReadModel{} = fixture) do
    params = %{
      title: fixture.title,
      slug: fixture.raw_slug,
      description: fixture.description,
      apparatusId: fixture.apparatusId,
      instrumentId: fixture.instrumentId
    }

    case Position.catalog_position(params) do
      {:ok, position} -> position
      {:error, reason} -> raise "cataloging fixture position failed: #{inspect(reason)}"
    end
  end
end
