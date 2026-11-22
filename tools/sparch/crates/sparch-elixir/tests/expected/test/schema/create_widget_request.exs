defmodule SportipediaWeb.Catalog.Equipment.Widget.Schemas.CreateWidgetRequestTest do
use ExUnit.Case
alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.CreateWidgetRequest
describe "CreateWidgetRequest" do
  test "schema/0 has the correct title" do
    assert %{title: "equipment.CreateWidgetRequest"} = CreateWidgetRequest.schema()
  end

  test "schema is an object" do
    assert %{type: :object} = CreateWidgetRequest.schema()
  end
end
end
