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
      cmd = %EditPosition{
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4(),
        slug: "sample-slug",
        title: "sample-title",
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

    test "accepts the slug the position already owns" do
      assert {:ok, created} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "owned-slug-#{UUID.uuid4()}"
               })

      assert {:ok, edited} = Position.edit_position(%{id: created.id, slug: created.slug})

      assert edited.id == created.id
      assert edited.slug == created.slug
    end

    test "rejects the slug another position holds" do
      assert {:ok, held} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "held-slug-#{UUID.uuid4()}"
               })

      assert {:ok, edited} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "edited-slug-#{UUID.uuid4()}"
               })

      assert {:error, {:validation_failure, errors}} =
               Position.edit_position(%{id: edited.id, slug: held.slug})

      assert errors[:slug] == [:slug_exists]
    end

    test "rejects an equipment reference the patch re-supplies that the catalog does not hold" do
      assert {:ok, created} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "dangling-slug-#{UUID.uuid4()}"
               })

      assert {:error, {:validation_failure, errors}} =
               Position.edit_position(%{id: created.id, apparatusId: UUID.uuid4()})

      assert errors[:apparatusId] == [:equipment_not_found]
    end

    test "rejects a patch naming both pieces of equipment" do
      assert {:ok, apparatus} =
               Apparatus.catalog_apparatus(%{
                 title: "sample-title",
                 slug: "one-off-#{UUID.uuid4()}"
               })

      assert {:ok, instrument} =
               Instrument.catalog_instrument(%{
                 title: "sample-title",
                 slug: "one-off-#{UUID.uuid4()}"
               })

      assert {:ok, created} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "both-slug-#{UUID.uuid4()}"
               })

      assert {:error, {:validation_failure, errors}} =
               Position.edit_position(%{
                 id: created.id,
                 apparatusId: apparatus.id,
                 instrumentId: instrument.id
               })

      assert errors[:apparatusId] == [:only_one_equipment_allowed]
      assert errors[:instrumentId] == [:only_one_equipment_allowed]
    end

    test "accepts a patch naming a piece of equipment the catalog holds" do
      assert {:ok, apparatus} =
               Apparatus.catalog_apparatus(%{
                 title: "sample-title",
                 slug: "bound-#{UUID.uuid4()}"
               })

      assert {:ok, created} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "bound-slug-#{UUID.uuid4()}"
               })

      assert {:ok, edited} = Position.edit_position(%{id: created.id, apparatusId: apparatus.id})

      assert edited.apparatusId == apparatus.id
    end

    test "reads an instrument the patch names in the instrument catalog" do
      assert {:ok, instrument} =
               Instrument.catalog_instrument(%{
                 title: "sample-title",
                 slug: "bound-#{UUID.uuid4()}"
               })

      assert {:ok, created} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "bound-instrument-slug-#{UUID.uuid4()}"
               })

      assert {:ok, edited} =
               Position.edit_position(%{id: created.id, instrumentId: instrument.id})

      assert edited.instrumentId == instrument.id
    end

    test "leaves an equipment reference the patch does not name unexamined" do
      assert {:ok, apparatus} =
               Apparatus.catalog_apparatus(%{
                 title: "sample-title",
                 slug: "gone-#{UUID.uuid4()}"
               })

      assert {:ok, created} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "gone-slug-#{UUID.uuid4()}",
                 apparatusId: apparatus.id
               })

      assert :ok = Apparatus.archive_apparatus(apparatus.id)

      assert {:ok, untouched} = Position.edit_position(%{id: created.id, title: "New Title"})

      assert untouched.apparatusId == apparatus.id

      assert {:error, {:validation_failure, errors}} =
               Position.edit_position(%{id: created.id, apparatusId: apparatus.id})

      assert errors[:apparatusId] == [:equipment_not_found]
    end
  end

  describe "Command Handler" do
    test "handles EditPosition command and returns PositionEdited event" do
      cmd = %EditPosition{
        id: UUID.uuid4(),
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4(),
        slug: "sample-slug",
        title: "sample-title"
      }

      events = EditPositionHandler.handle(%PositionAggregate{}, cmd)

      assert %PositionEdited{} = events
    end

    test "carries every field of the patch into position-edited" do
      id = UUID.uuid4()
      apparatus_id = UUID.uuid4()

      cmd = %EditPosition{
        id: id,
        title: "New Title",
        slug: "new-slug",
        description: "New description",
        apparatusId: apparatus_id
      }

      event = EditPositionHandler.handle(%PositionAggregate{}, cmd)

      assert event.id == id
      assert event.title == "New Title"
      assert event.slug == "new-slug"
      assert event.description == "New description"
      assert event.apparatusId == apparatus_id
    end

    test "lowers the slug the patch carries" do
      cmd = %EditPosition{id: UUID.uuid4(), slug: "Ready-Stance"}

      event = EditPositionHandler.handle(%PositionAggregate{}, cmd)

      assert event.slug == "ready-stance"
    end

    test "leaves an equipment reference the patch does not carry out of the change set" do
      apparatus_id = UUID.uuid4()

      cmd = %EditPosition{
        id: UUID.uuid4(),
        title: "New Title",
        apparatusId: apparatus_id
      }

      event = EditPositionHandler.handle(%PositionAggregate{}, cmd)

      assert event.instrumentId == nil

      assert PositionEdited.get_changes(event) == %{
               title: "New Title",
               apparatusId: apparatus_id
             }
    end

    test "carries no slug into the change set when the patch does not name one" do
      cmd = %EditPosition{id: UUID.uuid4(), title: "New Title"}

      event = EditPositionHandler.handle(%PositionAggregate{}, cmd)

      refute Map.has_key?(PositionEdited.get_changes(event), :slug)
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

    test "edit_position answers with the position the patch left behind" do
      assert {:ok, created} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "answer-slug-#{UUID.uuid4()}"
               })

      assert {:ok, edited} = Position.edit_position(%{id: created.id, title: "New Title"})

      assert edited.id == created.id
      assert edited.title == "New Title"
      assert edited.slug == created.slug
    end

    test "edit_position answers not_found for a position the catalog does not hold" do
      assert {:error, :not_found} =
               Position.edit_position(%{id: UUID.uuid4(), title: "New Title"})
    end

    test "edit_position returns validation errors" do
      assert {:ok, taken} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "returned-slug-#{UUID.uuid4()}"
               })

      assert {:ok, other} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "other-slug-#{UUID.uuid4()}"
               })

      assert {:error, {:validation_failure, _errors}} =
               Position.edit_position(%{id: other.id, slug: taken.slug})
    end

    test "edit_position lowers the slug it is given" do
      assert {:ok, created} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "lowered-slug-#{UUID.uuid4()}"
               })

      assert {:ok, edited} = Position.edit_position(%{id: created.id, slug: "LOWERED-Slug"})

      assert edited.slug == "lowered-slug"
    end

    test "edit_position keeps the equipment a patch does not speak about" do
      assert {:ok, apparatus} =
               Apparatus.catalog_apparatus(%{title: "sample-title", slug: "kept-#{UUID.uuid4()}"})

      assert {:ok, created} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "kept-slug-#{UUID.uuid4()}",
                 apparatusId: apparatus.id
               })

      assert {:ok, edited} = Position.edit_position(%{id: created.id, title: "New Title"})

      assert edited.apparatusId == apparatus.id
    end

    test "edit_position answers not_found for a position that left the catalog" do
      assert {:ok, created} =
               Position.catalog_position(%{
                 title: "sample-title",
                 slug: "departed-slug-#{UUID.uuid4()}"
               })

      assert :ok = Position.archive_position(created.id)

      assert {:error, :not_found} = Position.edit_position(%{id: created.id, title: "New Title"})
    end
  end
end
