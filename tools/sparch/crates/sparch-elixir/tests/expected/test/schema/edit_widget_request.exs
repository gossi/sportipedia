defmodule SportipediaWeb.Catalog.Equipment.Widget.Schemas.EditWidgetRequestTest do
use ExUnit.Case
alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.EditWidgetRequest
describe "EditWidgetRequest" do
  test "schema/0 has the correct title" do
    assert %{title: "equipment.EditWidgetRequest"} = EditWidgetRequest.schema()
  end

  test "schema is an object" do
    assert %{type: :object} = EditWidgetRequest.schema()
  end
end
end
