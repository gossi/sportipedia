defmodule SportipediaWeb.Catalog.Athlete.Position.Schemas.PositionResponseTest do
  use ExUnit.Case
  alias SportipediaWeb.Catalog.Athlete.Position.Schemas.PositionResponse

  describe "PositionResponse" do
    test "schema/0 has the correct title" do
      assert %{title: "athlete.Position"} = PositionResponse.schema()
    end

    test "schema is an object" do
      assert %{type: :object} = PositionResponse.schema()
    end
  end
end
