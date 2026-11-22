defmodule Sportipedia.Catalog.Equipment.Widget.Operation.ReadWidgetTest do
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
  test "denies or allows guests for read_widget" do
    assert Policy.authorize(:read_widget, nil, %{}) == :ok
  end

  test "allows users for read_widget" do
    assert Policy.authorize(:read_widget, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
  end
end
describe "Public API" do
  test "read_widget returns :not_found for unknown widget" do
    assert {:error, :not_found} = Widget.read_widget(UUID.uuid4())
  end
end
end
