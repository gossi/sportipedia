defmodule SportipediaWeb.Catalog.Equipment.Widget.Schemas.NoteWidgetRequestTest do
use ExUnit.Case
alias SportipediaWeb.Catalog.Equipment.Widget.Schemas.NoteWidgetRequest
describe "NoteWidgetRequest" do
  test "schema/0 has the correct title" do
    assert %{title: "equipment.NoteWidgetRequest"} = NoteWidgetRequest.schema()
  end

  test "schema is an object" do
    assert %{type: :object} = NoteWidgetRequest.schema()
  end
end
end
