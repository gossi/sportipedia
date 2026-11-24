defmodule SportipediaWeb.Catalog.Equipment.Widget.WidgetViewTest do
use SportipediaWeb.ConnCase
alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel
alias SportipediaWeb.Catalog.Equipment.Widget.WidgetView
describe "type/0" do
  test "returns widget" do
    assert WidgetView.type() == "widget"
  end
end
describe "fields/0" do
  test "returns the widget fields" do
    assert WidgetView.fields() == [:title, :slug, :archived_at, :coach_id, :description, :label, :team_id]
  end
end
describe "path/0" do
  test "returns the widget path" do
    assert WidgetView.path() == "catalog/equipment/widgets"
  end
end
describe "render show.json" do
  test "produces JSON:API single document" do
    widget = %WidgetReadModel{id: "d290f1ee-6c54-4b01-90e6-d701748f0851", title: "Classic Widget", slug: "classic-widget", archived_at: DateTime.utc_now(), coach_id: UUID.uuid5(:dns, "equipment:coach:head-coach"), description: "The original widget of the fixture world", label: "classic", team_id: UUID.uuid5(:dns, "equipment:team:first-team")}

    conn = build_conn() |> fetch_query_params()

    result = WidgetView.render("show.json", %{data: widget, conn: conn})

    assert %{data: %{id: "d290f1ee-6c54-4b01-90e6-d701748f0851", type: "widget"}} =
             result
  end
end
end
