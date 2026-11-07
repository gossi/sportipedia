defmodule Sportipedia.Catalog.Athlete.Position.Operation.ReadPositionTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Policy
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.Catalog.Athlete.Position.Queries.ReadPosition
  @moduletag :integration
  describe "Query" do
    test "answers the position addressed by its id" do
      position = new_position()

      assert Repo.one(ReadPosition.new(position.id)) == position
    end

    test "answers the position addressed by a slug of any letter case" do
      position = new_position(%{slug: "handstand"})

      assert Repo.one(ReadPosition.new("HandStand")) == position
    end

    test "answers no position for a slug that is not in the catalog" do
      assert Repo.one(ReadPosition.new("not-in-the-catalog")) == nil
    end
  end

  describe "Policy" do
    test "denies or allows guests for read_position" do
      assert Policy.authorize(:read_position, nil, %{}) == :ok
    end

    test "allows users for read_position" do
      assert Policy.authorize(:read_position, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
    end

    test "allows admins for read_position" do
      assert Policy.authorize(:read_position, %{id: UUID.uuid4(), role: "admin"}, %{}) == :ok
    end
  end

  describe "Public API" do
    test "read_position returns :not_found for unknown position" do
      assert {:error, :not_found} = Position.read_position(UUID.uuid4())
    end

    test "read_position answers the full position addressed by its id" do
      position =
        new_position(%{
          title: "Starting Block Position",
          slug: "starting-block-position",
          description: "Crouched stance against the starting blocks",
          apparatusId: UUID.uuid4()
        })

      assert {:ok, found} = Position.read_position(position.id)

      assert found.id == position.id
      assert found.title == "Starting Block Position"
      assert found.slug == "starting-block-position"
      assert found.description == "Crouched stance against the starting blocks"
      assert found.apparatusId == position.apparatusId
      assert found.instrumentId == nil
    end

    test "read_position answers the position addressed by its slug" do
      position = new_position(%{title: "Handstand", slug: "handstand"})

      assert {:ok, found} = Position.read_position("handstand")
      assert found.id == position.id
      assert found.title == "Handstand"
    end

    test "read_position answers not found for a position that left the catalog" do
      position = new_position()

      Repo.delete!(position)

      assert {:error, :not_found} = Position.read_position(position.id)
    end
  end

  defp new_position(attrs \\ %{}) do
    defaults = %{id: UUID.uuid4(), title: "Handstand", slug: "handstand-#{UUID.uuid4()}"}

    %PositionReadModel{}
    |> PositionReadModel.insert_changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end
end
