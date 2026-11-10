defmodule Sportipedia.Catalog.Athlete.Position.Operation.ArchivePositionTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Command.ArchivePosition
  alias Sportipedia.Catalog.Athlete.Position.Command.ArchivePositionHandler
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionArchived
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionCataloged
  alias Sportipedia.Catalog.Athlete.Position.Policy
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  @moduletag :integration
  describe "Command" do
    test "requires id" do
      assert_raise ArgumentError, fn ->
        struct!(ArchivePosition, %{})
      end
    end

    test "id cannot be nil" do
      cmd = %ArchivePosition{id: nil}

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
    test "handles ArchivePosition command and returns PositionArchived event" do
      cmd = %ArchivePosition{id: UUID.uuid5(:dns, "athlete:position:unicycle-riding")}

      events = ArchivePositionHandler.handle(%PositionAggregate{}, cmd)

      assert %PositionArchived{} = events
    end
  end

  describe "Policy" do
    test "denies or allows guests for archive_position" do
      assert Policy.authorize(:archive_position, nil, %{}) == :error
    end

    test "denies an authenticated user who is not an admin for archive_position" do
      assert Policy.authorize(:archive_position, %{id: UUID.uuid4(), role: "user"}, %{}) == :error
    end

    test "allows admins for archive_position" do
      assert Policy.authorize(:archive_position, %{id: UUID.uuid4(), role: "admin"}, %{}) == :ok
    end
  end

  describe "Public API" do
    test "archive_position succeeds" do
      assert {:ok, created} = Position.catalog_position(%{title: "Riding", slug: "riding"})

      assert :ok = Position.archive_position(created.id)
    end

    test "archive_position fails for an unknown position" do
      assert {:error, _} = Position.archive_position(UUID.uuid4())
    end

    test "archive removes the catalog entry: read answers not found and a deleted id cannot be archived again" do
      {:ok, created} =
        Position.catalog_position(%{title: "On Tire", slug: "on-tire-archive-chain"})

      assert :ok = Position.archive_position(created.id)
      assert {:error, :not_found} = Position.read_position(created.id)

      # The catalog entry is gone, so there is no archived state to re-archive.
      assert {:error, :not_found} = Position.archive_position(created.id)
    end

    test "archive frees the slug: the same raw slug can be cataloged again after deletion" do
      {:ok, deleted} =
        Position.catalog_position(%{title: "Lunge Position", slug: "lunge-position"})

      assert :ok = Position.archive_position(deleted.id)

      assert {:ok, recreated} =
               Position.catalog_position(%{title: "Lunge Position", slug: "lunge-position"})

      assert recreated.id != deleted.id
    end

    test "position-archived stays in the event store after the catalog entry is deleted" do
      {:ok, created} = Position.catalog_position(%{title: "Seat in-front", slug: "seat-in-front"})

      assert :ok = Position.archive_position(created.id)

      stream =
        Commanded.EventStore.stream_forward(
          Sportipedia.Catalog,
          "athlete/position/" <> created.id
        )

      id = created.id

      assert [%PositionCataloged{id: ^id}, %PositionArchived{id: ^id}] =
               Enum.map(stream, & &1.data)
    end
  end
end
