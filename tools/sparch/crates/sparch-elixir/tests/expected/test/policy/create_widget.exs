defmodule Sportipedia.Catalog.Equipment.Widget.Operation.CreateWidgetTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget.Policy
@moduletag :integration
describe "Policy" do
  test "denies or allows guests for create_widget" do
    assert Policy.authorize(:create_widget, nil, %{}) == :error
  end

  test "allows users for create_widget" do
    assert Policy.authorize(:create_widget, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
  end
end
end
