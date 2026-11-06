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
      # `Repo.get/2`, which raises, and the command never got to answer. `allow_blank`
      # on the `validates` line keeps the lookup off an absent address, so
      # `presence` is the only rule that speaks for the id.
      assert id_rules_that_failed(cmd) == [:presence]
    end

    test "id cannot be blank" do
      cmd = %ArchivePosition{id: ""}

      assert id_rules_that_failed(cmd) == [:presence]
    end

    test "an id that is not an id is unknown" do
      # A malformed address denotes no position, which is what the existence
      # rule answers — and it must not raise on the way to the database.
      cmd = %ArchivePosition{id: "not-a-uuid"}

      assert id_rules_that_failed(cmd) == [:by]
    end
  end

  describe "Policy" do
    test "denies or allows guests for archive_position" do
      assert Policy.authorize(:archive_position, nil, %{}) == :error
    end

    # The model's actor list for archive-position is `admin`, so the generated
    # `is_user?` allowance is too permissive: an authenticated non-admin is
    # denied. Authorization itself stays at the controller's Bodyguard plug
    # (ADR-0001); this is the same answer either way.
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
    end

    test "archiving removes the position from the catalog" do
      slug = "pos-789-#{UUID.uuid4()}"
      {:ok, created} = Position.catalog_position(%{title: "To Archive", slug: slug})

      assert :ok = Position.archive_position(created.id)

      # `position-archived` is a complete delete fact: the row is gone, the read
      # answers :not_found, and there is no unarchive to call — archiving a
      # position is final. The event itself stays in the store as the audit trail.
      assert Repo.get(PositionReadModel, created.id) == nil
      assert {:error, :not_found} = Position.read_position(created.id)
      assert {:error, :not_found} = Position.read_position(slug)
    end

    test "archiving twice is answered by the position's own existence check" do
      {:ok, created} =
        Position.catalog_position(%{title: "Twice", slug: "twice-#{UUID.uuid4()}"})

      assert :ok = Position.archive_position(created.id)
      assert {:error, :not_found} = Position.archive_position(created.id)
    end

    test "archiving frees the slug for reuse" do
      slug = "reusable-#{UUID.uuid4()}"
      {:ok, created} = Position.catalog_position(%{title: "Reusable", slug: slug})
      assert :ok = Position.archive_position(created.id)

      assert {:ok, reused} = Position.catalog_position(%{title: "Reusable Again", slug: slug})
      assert reused.id != created.id
      assert reused.slug == slug
    end

    test "archive_position fails for an unknown position" do
      assert {:error, :not_found} = Position.archive_position(UUID.uuid4())
    end
  end

  describe "Command Handler" do
    test "handles ArchivePosition command and returns PositionArchived event" do
      cmd = %ArchivePosition{id: UUID.uuid4()}

      events = ArchivePositionHandler.handle(%PositionAggregate{}, cmd)

      assert %PositionArchived{} = events
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
