defmodule SportipediaWeb.Catalog.Athlete.Position.Schemas.EditPositionRequestTest do
  use ExUnit.Case
  alias SportipediaWeb.Catalog.Athlete.Position.Schemas.EditPositionRequest

  describe "EditPositionRequest" do
    test "schema/0 has the correct title" do
      assert %{title: "athlete.EditPositionRequest"} = EditPositionRequest.schema()
    end

    test "schema is an object" do
      assert %{type: :object} = EditPositionRequest.schema()
    end
  end
end
