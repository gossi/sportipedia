defmodule Sportipedia.Catalog.Athlete.Position.Operation.EditPositionTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Command.EditPosition
  alias Sportipedia.Catalog.Athlete.Position.Command.EditPositionHandler
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionEdited
  alias Sportipedia.Catalog.Athlete.Position.Policy
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Instrument
  @moduletag :integration
  describe "Command" do
    test "requires id" do
      assert_raise ArgumentError, fn ->
        struct!(EditPosition, %{})
      end
    end

    test "id cannot be nil" do
      # Rejected, not raised: the existence check used to hand the nil to
      # `Repo.get/2`, which raises, and the command never got to answer.
      # `allow_blank` on the `validates` line keeps the lookup off an absent
      # address, so `presence` is the only rule that speaks for the id.
      assert id_rules_that_failed(%EditPosition{id: nil}) == [:presence]
    end

    test "id cannot be blank" do
      assert id_rules_that_failed(%EditPosition{id: ""}) == [:presence]
    end

    test "an id that is not an id is unknown" do
      # A malformed address denotes no position, which is what the existence rule
      # answers — and it must not raise on the way to the database.
      assert id_rules_that_failed(%EditPosition{id: "not-a-uuid"}) == [:by]
    end

    test "an id that is not in the catalog is unknown, never absent" do
      # A well-formed address nobody holds is the existence rule's to answer:
      # `[:by]`, which the client sees as 404 — not `[:presence]`, which would
      # claim the caller never named a position at all.
      assert id_rules_that_failed(%EditPosition{id: UUID.uuid4()}) == [:by]
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
      assert {:ok, created} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "sample-slug-#{UUID.uuid4()}"
               })

      assert {:ok, read_model} = Position.edit_position(%{id: created.id})

      assert read_model.id == created.id
    end

    test "edits one field and leaves the fields the patch does not carry" do
      slug = "old-title-#{UUID.uuid4()}"

      {:ok, created} =
        Position.catalog_position(%{
          title: "Old Title",
          slug: slug,
          description: "Unchanged description"
        })

      assert {:ok, edited} = Position.edit_position(%{id: created.id, title: "New Title"})

      assert edited.id == created.id
      assert edited.title == "New Title"
      # presence-merge: an absent field changes nothing.
      assert edited.slug == slug
      assert edited.description == "Unchanged description"

      assert {:ok, read_back} = Position.read_position(created.id)
      assert read_back.title == "New Title"
      assert read_back.slug == slug
      assert read_back.description == "Unchanged description"
    end

    test "stores a slug an edit supplies in mixed case in its canonical form" do
      slug = "mixed-#{UUID.uuid4()}"

      {:ok, created} =
        Position.catalog_position(%{title: "Mixed Case", slug: "origin-#{UUID.uuid4()}"})

      assert {:ok, edited} = Position.edit_position(%{id: created.id, slug: String.upcase(slug)})

      assert edited.slug == slug
      assert {:ok, read_back} = Position.read_position(slug)
      assert read_back.id == created.id
    end

    test "accepts the slug the position already owns" do
      slug = "keep-me-#{UUID.uuid4()}"
      {:ok, created} = Position.catalog_position(%{title: "Keep Me", slug: slug})

      assert {:ok, edited} = Position.edit_position(%{id: created.id, slug: slug})
      assert edited.slug == slug
    end

    test "rejects a slug another position owns" do
      {:ok, taken} = Position.catalog_position(%{title: "Taken", slug: "taken-#{UUID.uuid4()}"})

      {:ok, other} =
        Position.catalog_position(%{title: "Other", slug: "other-#{UUID.uuid4()}"})

      assert {:error, {:validation_failure, failures}} =
               Position.edit_position(%{id: other.id, slug: taken.slug})

      assert failures == %{slug: [:slug_exists]}
      assert {:ok, unchanged} = Position.read_position(other.id)
      assert unchanged.slug == other.slug
    end

    test "rejects an equipment reference that only the merged state makes ambiguous" do
      {:ok, apparatus} = Apparatus.catalog_apparatus(%{title: "Parallel Bars", slug: "pb"})
      {:ok, instrument} = Instrument.catalog_instrument(%{title: "Drum", slug: "drum"})

      {:ok, created} =
        Position.catalog_position(%{
          title: "Support",
          slug: "support-#{UUID.uuid4()}",
          apparatusId: apparatus.id
        })

      # The patch alone carries one reference; the stored position carries the
      # other. The rule is decided on the effective state — the patch merged over
      # what the position holds — so the rejection is a validation failure, and
      # the slug of the violation is the apparatus reference the store already
      # holds.
      assert {:error, {:validation_failure, failures}} =
               Position.edit_position(%{id: created.id, instrumentId: instrument.id})

      assert failures == %{apparatusId: [:at_most_one_equipment]}

      assert {:ok, unchanged} = Position.read_position(created.id)
      assert unchanged.apparatusId == apparatus.id
      assert unchanged.instrumentId == nil
    end

    test "rejects an apparatus reference that only the merged state makes ambiguous" do
      {:ok, apparatus} = Apparatus.catalog_apparatus(%{title: "Pommel Horse", slug: "ph"})
      {:ok, instrument} = Instrument.catalog_instrument(%{title: "Cymbal", slug: "cymbal"})

      {:ok, created} =
        Position.catalog_position(%{
          title: "Crash",
          slug: "crash-#{UUID.uuid4()}",
          instrumentId: instrument.id
        })

      # The same rule seen from the other side: the patch carries the apparatus
      # while the stored position carries the instrument.
      assert {:error, {:validation_failure, failures}} =
               Position.edit_position(%{id: created.id, apparatusId: apparatus.id})

      assert failures == %{apparatusId: [:at_most_one_equipment]}
    end

    test "accepts a patch that re-supplies the reference the position already holds" do
      {:ok, apparatus} = Apparatus.catalog_apparatus(%{title: "Beam", slug: "beam"})

      {:ok, created} =
        Position.catalog_position(%{
          title: "Split",
          slug: "split-#{UUID.uuid4()}",
          apparatusId: apparatus.id
        })

      # Merging the patch over the stored state must not turn one reference into
      # two: the effective state still holds the apparatus alone.
      assert {:ok, edited} =
               Position.edit_position(%{
                 id: created.id,
                 apparatusId: apparatus.id,
                 title: "Split Scale"
               })

      assert edited.title == "Split Scale"
      assert edited.apparatusId == apparatus.id
      assert edited.instrumentId == nil

      # The other side merges the same way.
      {:ok, instrument} = Instrument.catalog_instrument(%{title: "Maracas", slug: "maracas"})

      {:ok, with_instrument} =
        Position.catalog_position(%{
          title: "Roll",
          slug: "roll-#{UUID.uuid4()}",
          instrumentId: instrument.id
        })

      assert {:ok, edited} =
               Position.edit_position(%{
                 id: with_instrument.id,
                 instrumentId: instrument.id,
                 title: "Roll Up"
               })

      assert edited.title == "Roll Up"
      assert edited.instrumentId == instrument.id
      assert edited.apparatusId == nil
    end

    test "judges an unresolvable address by its existence rule alone" do
      {:ok, instrument} = Instrument.catalog_instrument(%{title: "Triangle", slug: "triangle"})

      # There is no stored position to merge with, and the address must not even
      # be looked up: `Repo.get/2` raises on a value that cannot denote a row.
      assert {:error, :not_found} =
               Position.edit_position(%{id: "not-a-uuid", instrumentId: instrument.id})
    end

    test "rejects a patch that carries both equipment references" do
      {:ok, apparatus} = Apparatus.catalog_apparatus(%{title: "Rings", slug: "rings"})
      {:ok, instrument} = Instrument.catalog_instrument(%{title: "Flute", slug: "flute"})

      {:ok, created} =
        Position.catalog_position(%{title: "Both Sides", slug: "both-#{UUID.uuid4()}"})

      assert {:error, {:validation_failure, failures}} =
               Position.edit_position(%{
                 id: created.id,
                 apparatusId: apparatus.id,
                 instrumentId: instrument.id
               })

      # The rule is one rule, so it speaks once, on the field the model names
      # first: `at-most-one-equipment` is about the apparatus reference.
      assert failures == %{apparatusId: [:at_most_one_equipment]}
    end

    test "rejects an equipment reference the patch re-supplies that is not in the catalog" do
      # The same rule catalog-position enforces, seen from the patch: the
      # instrument half answers on the field the patch carries, with the model's
      # single equipment atom.
      {:ok, created} =
        Position.catalog_position(%{title: "Piano", slug: "piano-#{UUID.uuid4()}"})

      assert {:error, {:validation_failure, failures}} =
               Position.edit_position(%{id: created.id, instrumentId: UUID.uuid4()})

      assert failures == %{instrumentId: [:equipment_not_found]}
    end

    test "rejects an apparatus slug where an apparatus id belongs on a patch" do
      # A legal reference is an id: the existence rule guards the value before
      # asking the equipment port, so the slug answers 422 instead of ever
      # reaching the reference column.
      {:ok, apparatus} = Apparatus.catalog_apparatus(%{title: "Parallel Bars", slug: "pb-ref"})

      {:ok, created} =
        Position.catalog_position(%{title: "Bar Hold", slug: "bar-hold-#{UUID.uuid4()}"})

      assert {:error, {:validation_failure, failures}} =
               Position.edit_position(%{id: created.id, apparatusId: apparatus.slug})

      assert failures == %{apparatusId: [:equipment_not_found]}
    end

    test "does not re-validate an equipment reference the patch does not carry" do
      {:ok, apparatus} = Apparatus.catalog_apparatus(%{title: "Vaulting Table", slug: "vt"})

      {:ok, created} =
        Position.catalog_position(%{
          title: "Vault Approach",
          slug: "vault-approach-#{UUID.uuid4()}",
          apparatusId: apparatus.id
        })

      # Equipment is archived without cascading to the positions that reference
      # it, so the stored position now points at a missing apparatus.
      :ok = Apparatus.archive_apparatus(apparatus.id)

      assert {:ok, edited} = Position.edit_position(%{id: created.id, title: "Vault Take-off"})
      assert edited.title == "Vault Take-off"
      assert edited.apparatusId == apparatus.id

      # A reference the patch re-supplies is checked: this one is not there.
      assert {:error, {:validation_failure, failures}} =
               Position.edit_position(%{id: created.id, apparatusId: apparatus.id})

      assert failures == %{apparatusId: [:equipment_not_found]}
    end

    test "rejects editing a position that is not there" do
      assert {:error, :not_found} = Position.edit_position(%{id: UUID.uuid4(), title: "Nobody"})
    end

    test "rejects editing a position that has left the catalog" do
      {:ok, created} =
        Position.catalog_position(%{title: "Lunge Position", slug: "lunge-#{UUID.uuid4()}"})

      :ok = Position.archive_position(created.id)

      # An archive is a delete: the position is not in a special state an edit
      # could still reach, so the address resolves to nothing.
      assert {:error, :not_found} = Position.edit_position(%{id: created.id, title: "Renamed"})
    end
  end

  describe "Command Handler" do
    test "judges the equipment rule on the merged state, inside the aggregate stream" do
      # `at-most-one-equipment` is an aggregate invariant: the handler decides it
      # over the patch merged onto the state the events built. Execution is
      # serialized per stream, so no second writer can slip the other reference
      # in between — and nothing here reads the projection.
      stored = %PositionAggregate{
        id: UUID.uuid4(),
        title: "Support",
        slug: "support",
        apparatusId: UUID.uuid4()
      }

      cmd = %EditPosition{id: stored.id, instrumentId: UUID.uuid4()}

      assert {:error, {:validation_failure, failures}} =
               EditPositionHandler.handle(stored, cmd)

      assert failures == %{apparatusId: [:at_most_one_equipment]}
    end

    test "handles EditPosition command and returns PositionEdited event" do
      cmd = %EditPosition{
        id: UUID.uuid4(),
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: nil,
        slug: "sample-slug",
        title: "sample-title"
      }

      events = EditPositionHandler.handle(%PositionAggregate{}, cmd)

      assert %PositionEdited{} = events
    end

    test "emits id plus only the fields the patch carries" do
      stored = %PositionAggregate{
        id: UUID.uuid4(),
        title: "Old Title",
        slug: "old-title",
        description: "Stored description",
        apparatusId: UUID.uuid4(),
        instrumentId: nil
      }

      cmd = %EditPosition{id: stored.id, title: "New Title"}

      event = EditPositionHandler.handle(stored, cmd)

      assert %PositionEdited{id: id, title: "New Title"} = event
      assert id == stored.id
      # Only the changed fields travel: the rest is the projector's and the
      # aggregate's to keep.
      assert PositionEdited.get_changes(event) == %{title: "New Title"}
      assert event.slug == nil
      assert event.description == nil
      assert event.apparatusId == nil
      assert event.instrumentId == nil
    end

    test "emits the slug it is given in its canonical form" do
      stored = %PositionAggregate{id: UUID.uuid4(), title: "Old Title", slug: "old-title"}
      cmd = %EditPosition{id: stored.id, slug: "MiXeD-Case"}

      event = EditPositionHandler.handle(stored, cmd)

      # The slug is stored lowercase, so the fact carries the canonical form;
      # `unique-slug` compares against it the same way.
      assert PositionEdited.get_changes(event) == %{slug: "mixed-case"}
    end
  end

  # The rules that failed for a command's `id`.
  defp id_rules_that_failed(cmd) do
    cmd
    |> Vex.errors()
    |> Enum.flat_map(fn {_error, field, rule, _message} ->
      if field == :id, do: [rule], else: []
    end)
  end
end
