defmodule SportipediaWeb.Catalog.Athlete.Position.Schemas.ListPositionsQueryParamsTest do
  use ExUnit.Case
  alias SportipediaWeb.Catalog.Athlete.Position.Schemas.ListPositionsQueryParams

  describe "ListPositionsQueryParams" do
    test "schema/0 has the correct title" do
      assert %{title: "athlete.ListPositionsQueryParams"} = ListPositionsQueryParams.schema()
    end

    test "schema is an object" do
      assert %{type: :object} = ListPositionsQueryParams.schema()
    end
  end
end
