defmodule SportipediaWeb.Catalog.Athlete.Position.Schemas.PositionCollectionResponseTest do
  use ExUnit.Case
  alias SportipediaWeb.Catalog.Athlete.Position.Schemas.PositionCollectionResponse

  describe "PositionCollectionResponse" do
    test "schema/0 has the correct title" do
      assert %{title: "athlete.Positions"} = PositionCollectionResponse.schema()
    end

    test "schema is an object" do
      assert %{type: :object} = PositionCollectionResponse.schema()
    end
  end
end
