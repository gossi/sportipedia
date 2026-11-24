defmodule Sportipedia.Catalog.Equipment.Widget.Event.WidgetRenameLoggedTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetRenameLogged
alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate
@moduletag :integration
describe "Event" do
  test "creates WidgetRenameLogged with required fields" do
    event = struct!(WidgetRenameLogged, %{id: UUID.uuid5(:dns, "equipment:widget:classic-widget")})

    assert event.id != nil
  end

  test "requires enforced fields" do
    assert_raise ArgumentError, fn ->
      struct!(WidgetRenameLogged, %{})
    end
  end

  test "serializes to JSON" do
    event = struct!(WidgetRenameLogged, %{id: UUID.uuid5(:dns, "equipment:widget:classic-widget")})

    assert {:ok, _json} = Jason.encode(event)
  end
end
describe "Aggregate" do
  test "applies widget-rename-logged to aggregate state" do
    event = %WidgetRenameLogged{id: UUID.uuid5(:dns, "equipment:widget:classic-widget")}

    state = %WidgetAggregate{id: event.id}

  assert WidgetAggregate.apply(state, event) == state
  end
end
end
