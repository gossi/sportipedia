defmodule Sportipedia.Catalog.Equipment.Widget.Operation.CreateWidgetTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget
@moduletag :integration
describe "Public API" do
  test "create_widget succeeds" do
    assert {:ok, read_model} = Widget.create_widget(%{title: "Pommel Horse", slug: "sample-slug-#{UUID.uuid4()}"})

    assert read_model.id != nil
  end

  test "create_widget returns validation errors" do
    assert {:error, {:validation_failure, _errors}} = Widget.create_widget(%{})
  end
end
end
