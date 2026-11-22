defmodule SportipediaWeb.Catalog.Equipment.Widget.Schemas.ListWidgetsQueryParamsTest do
use ExUnit.Case
alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.ListWidgetsQueryParams
describe "ListWidgetsQueryParams" do
  test "schema/0 has the correct title" do
    assert %{title: "equipment.ListWidgetsQueryParams"} = ListWidgetsQueryParams.schema()
  end

  test "schema is an object" do
    assert %{type: :object} = ListWidgetsQueryParams.schema()
  end
end
end
