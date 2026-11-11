defmodule Sportipedia.Catalog.Athlete.Position.Operation.ReadPositionTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Policy
  alias Sportipedia.Catalog.Athlete.Position.Queries.ReadPosition
  alias Sportipedia.TestSupport.Catalog.Athlete
  alias Sportipedia.TestSupport.Catalog.Athlete.PositionFixtures
  @moduletag :integration

  describe "Query" do
    test "reads the position by its id" do
      {:ok, position} = Athlete.new_position(PositionFixtures.unicycle_riding())

      assert Repo.one(ReadPosition.new(position.id)) == position
    end

    test "reads the position by its canonical slug" do
      {:ok, position} = Athlete.new_position(PositionFixtures.unicycle_riding())

      assert Repo.one(ReadPosition.new("unicycle/riding")) == position
    end

    test "reads the unbound position by its bare slug" do
      {:ok, position} = Athlete.new_position(PositionFixtures.ready_stance())

      assert Repo.one(ReadPosition.new("ready-stance")) == position
    end

    test "does not read a position by its raw slug" do
      {:ok, position} = Athlete.new_position(PositionFixtures.unicycle_riding())

      assert Repo.one(ReadPosition.new(position.raw_slug)) == nil
    end

    test "does not read a position by its slug in another case" do
      {:ok, _position} = Athlete.new_position(PositionFixtures.unicycle_riding())

      assert Repo.one(ReadPosition.new("UNICYCLE/RIDING")) == nil
    end
  end

  describe "Policy" do
    test "denies or allows guests for read_position" do
      assert Policy.authorize(:read_position, nil, %{}) == :ok
    end

    test "allows users for read_position" do
      assert Policy.authorize(:read_position, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
    end
  end

  describe "Public API" do
    test "read_position returns the cataloged position" do
      {:ok, position} = Athlete.new_position(PositionFixtures.unicycle_riding())

      assert {:ok, ^position} = Position.read_position(position.id)
    end

    test "read_position returns :not_found for unknown position" do
      assert {:error, :not_found} = Position.read_position(UUID.uuid4())
    end
  end
end
