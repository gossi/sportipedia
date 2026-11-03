defmodule Sportipedia.Catalog.Athlete.Position.Operation.ListPositionsTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Policy
  @moduletag :integration

  describe "ListPositions query" do
    test "is a work in progress until the spec fills it" do
      # the query module body is the 1% the blueprint leaves to the spec
      assert true
    end
  end

  describe "Policy - list_positions" do
    test "denies or allows guests for list_positions" do
      assert Policy.authorize(:list_positions, nil, %{}) == :ok
    end

    test "allows users for list_positions" do
      assert Policy.authorize(:list_positions, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
    end
  end

  describe "Public API - list_positions" do
    test "list_positions lists read models" do
      assert {:ok, data} = Position.list_positions(%JSONAPI.Config{})

      assert is_list(data)
    end
  end
end
