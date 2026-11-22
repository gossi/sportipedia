defmodule SportipediaWeb.Catalog.Equipment.Widget.Schemas.RelabelWidgetRequestTest do
use ExUnit.Case
alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.RelabelWidgetRequest
describe "RelabelWidgetRequest" do
  test "schema/0 has the correct title" do
    assert %{title: "equipment.RelabelWidgetRequest"} = RelabelWidgetRequest.schema()
  end

  test "schema is an object" do
    assert %{type: :object} = RelabelWidgetRequest.schema()
  end
end
end
