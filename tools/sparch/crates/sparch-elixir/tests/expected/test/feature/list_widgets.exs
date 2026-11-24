defmodule Sportipedia.Catalog.Equipment.Widget.Operation.ListWidgetsTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget
alias Sportipedia.Catalog.Equipment.Widget.Policy
@moduletag :integration
describe "Query" do
  test "is a work in progress until the spec fills it" do
    # the query module body is the 1% the blueprint leaves to the spec
    assert true
  end
end
describe "Policy" do
  test "denies or allows guests for list_widgets" do
    assert Policy.authorize(:list_widgets, nil, %{}) == :ok
  end

  test "allows users for list_widgets" do
    assert Policy.authorize(:list_widgets, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
  end
end
describe "Public API" do
  test "list_widgets lists read models" do
    assert {:ok, data} = Widget.list_widgets(%JSONAPI.Config{})

    assert is_list(data)
  end
end
end
