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
      # other. Command-level Vex cannot see that, so the handler decides on the
      # merged state — and the client is owed the same 422-shaped rejection.
      assert {:error, {:validation_failure, failures}} =
               Position.edit_position(%{id: created.id, instrumentId: instrument.id})

      assert failures == %{instrumentId: [:at_most_one_equipment]}

      assert {:ok, unchanged} = Position.read_position(created.id)
      assert unchanged.apparatusId == apparatus.id
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

      assert failures == %{instrumentId: [:at_most_one_equipment]}
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
  end

  describe "Command Handler" do
    test "handles EditPosition command and returns PositionEdited event" do
      # A patch that carries only one side of the equipment pair: a command with
      # both references violates at-most-one-equipment and the handler rejects it.
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

    test "rejects a patch that only the merged state makes ambiguous" do
      stored = %PositionAggregate{
        id: UUID.uuid4(),
        title: "Support",
        slug: "support",
        apparatusId: UUID.uuid4(),
        instrumentId: nil
      }

      cmd = %EditPosition{id: stored.id, instrumentId: UUID.uuid4()}

      assert EditPositionHandler.handle(stored, cmd) == {:error, :at_most_one_equipment}
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
