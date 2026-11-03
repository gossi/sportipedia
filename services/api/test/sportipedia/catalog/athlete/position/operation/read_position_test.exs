defmodule Sportipedia.Catalog.Athlete.Position.Operation.ReadPositionTest do
  use Sportipedia.CatalogTestCase
  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.Policy
  @moduletag :integration

  describe "ReadPosition query" do
    test "is a work in progress until the spec fills it" do
      # the query module body is the 1% the blueprint leaves to the spec
      assert true
    end
  end

  describe "Policy - read_position" do
    test "denies or allows guests for read_position" do
      assert Policy.authorize(:read_position, nil, %{}) == :ok
    end

    test "allows users for read_position" do
      assert Policy.authorize(:read_position, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
    end
  end

  describe "Public API - read_position" do
    test "read_position returns :not_found for unknown position" do
      assert {:error, :not_found} = Position.read_position(UUID.uuid4())
    end
  end
end
