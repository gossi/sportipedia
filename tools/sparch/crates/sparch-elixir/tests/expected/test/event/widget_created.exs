defmodule Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreatedTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated
@moduletag :integration
describe "Event" do
  test "creates WidgetCreated with required fields" do
    event = struct!(WidgetCreated, %{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), title: "Classic Widget", slug: "classic-widget", coach_id: UUID.uuid5(:dns, "equipment:coach:head-coach"), description: "The original widget of the fixture world", label: "classic", team_id: UUID.uuid5(:dns, "equipment:team:first-team")})

    assert event.id != nil
  end

  test "requires enforced fields" do
    assert_raise ArgumentError, fn ->
      struct!(WidgetCreated, %{})
    end
  end

  test "serializes to JSON" do
    event = struct!(WidgetCreated, %{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), title: "Classic Widget", slug: "classic-widget", coach_id: UUID.uuid5(:dns, "equipment:coach:head-coach"), description: "The original widget of the fixture world", label: "classic", team_id: UUID.uuid5(:dns, "equipment:team:first-team")})

    assert {:ok, _json} = Jason.encode(event)
  end
end
end
