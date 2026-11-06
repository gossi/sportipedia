defmodule SportipediaWeb.Catalog.Athlete.Position.Schemas.CatalogPositionRequestTest do
  use ExUnit.Case
  alias SportipediaWeb.Catalog.Athlete.Position.Schemas.CatalogPositionRequest

  describe "CatalogPositionRequest" do
    test "schema/0 has the correct title" do
      assert %{title: "athlete.CatalogPositionRequest"} = CatalogPositionRequest.schema()
    end

    test "schema is an object" do
      assert %{type: :object} = CatalogPositionRequest.schema()
    end
  end
end
