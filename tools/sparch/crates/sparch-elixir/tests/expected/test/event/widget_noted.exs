defmodule Sportipedia.Catalog.Equipment.Widget.Event.WidgetNotedTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetNoted
alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate
@moduletag :integration
describe "Event" do
  test "creates WidgetNoted with required fields" do
    event = struct!(WidgetNoted, %{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), comment: "sample-comment"})

    assert event.id != nil
  end

  test "requires enforced fields" do
    assert_raise ArgumentError, fn ->
      struct!(WidgetNoted, %{})
    end
  end

  test "serializes to JSON" do
    event = struct!(WidgetNoted, %{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), comment: "sample-comment"})

    assert {:ok, _json} = Jason.encode(event)
  end
end
describe "Aggregate" do
  test "applies widget-noted to aggregate state" do
    event = %WidgetNoted{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), comment: "sample-comment"}

    state = %WidgetAggregate{id: event.id}

  assert WidgetAggregate.apply(state, event) == state
  end
end
end
