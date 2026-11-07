defmodule Sportipedia.Catalog.Athlete.Position.Operation.ArchivePositionTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Command.ArchivePosition
  alias Sportipedia.Catalog.Athlete.Position.Command.ArchivePositionHandler
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionArchived
  alias Sportipedia.Catalog.Athlete.Position.Policy
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
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

    test "rejects an id that is not a position in the catalog" do
      cmd = %ArchivePosition{id: UUID.uuid4()}

      assert Enum.any?(Vex.errors(cmd), fn
               {_severity, :id, _rule, message} -> message == :not_found
             end)
    end
  end

  describe "Command Handler" do
    test "handles ArchivePosition command and returns PositionArchived event" do
      cmd = %ArchivePosition{id: UUID.uuid4()}

      events = ArchivePositionHandler.handle(%PositionAggregate{}, cmd)

      assert %PositionArchived{} = events
    end

    test "states the removed position by the id it was addressed with" do
      id = UUID.uuid4()
      cmd = %ArchivePosition{id: id}

      assert %PositionArchived{} =
               event = ArchivePositionHandler.handle(%PositionAggregate{}, cmd)

      assert event.id == id
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
      assert {:ok, created} =
               Position.catalog_position(%{title: "sample-title", slug: "sample-slug"})

      assert :ok = Position.archive_position(created.id)

      # No read model follows the command, and none is left behind: the
      # position has left the catalog.
      assert Repo.get(PositionReadModel, created.id) == nil
    end

    test "archive_position fails for an unknown position" do
      assert {:error, :not_found} = Position.archive_position(UUID.uuid4())
    end

    test "re-archiving a removed position is rejected as not found" do
      assert {:ok, created} =
               Position.catalog_position(%{title: "sample-title", slug: "sample-slug"})

      assert :ok = Position.archive_position(created.id)

      # There is no archived state to re-archive and no restore operation:
      # once removed, the id addresses nothing.
      assert {:error, :not_found} = Position.archive_position(created.id)
    end

    test "a removed position frees its slug for a new one" do
      assert {:ok, created} =
               Position.catalog_position(%{title: "sample-title", slug: "sample-slug"})

      assert :ok = Position.archive_position(created.id)

      # The unique-slug invariant no longer sees the removed position: the
      # freed slug can be cataloged again.
      assert {:ok, replacement} =
               Position.catalog_position(%{title: "sample-title", slug: "sample-slug"})

      assert replacement.id != created.id
    end
  end
end
