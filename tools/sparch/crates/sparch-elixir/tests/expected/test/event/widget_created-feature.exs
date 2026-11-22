defmodule Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreatedTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated
alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate
alias Sportipedia.Catalog.Equipment.Widget.WidgetProjector
alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel
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
describe "Aggregate" do
  test "applies widget-created to aggregate state" do
    event = %WidgetCreated{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), title: "Classic Widget", slug: "classic-widget", coach_id: UUID.uuid5(:dns, "equipment:coach:head-coach"), description: "The original widget of the fixture world", label: "classic", team_id: UUID.uuid5(:dns, "equipment:team:first-team")}

    result = WidgetAggregate.apply(%WidgetAggregate{}, event)

  assert result.id == event.id
        assert result.title == event.title
        assert result.slug == event.slug
        assert result.coach_id == event.coach_id
        assert result.description == event.description
        assert result.label == event.label
        assert result.team_id == event.team_id
  end
end
describe "Projector" do
  test "projects WidgetCreated to the widget read model" do
    event = %WidgetCreated{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), title: "Classic Widget", slug: "classic-widget", coach_id: UUID.uuid5(:dns, "equipment:coach:head-coach"), description: "The original widget of the fixture world", label: "classic", team_id: UUID.uuid5(:dns, "equipment:team:first-team")}

    metadata = %{
      handler_name: "equipment.widget_projection",
      event_number: 1,
      event_id: UUID.uuid4(),
      stream_id: "widget-#{event.id}",
      stream_version: 1,
      correlation_id: nil,
      causation_id: nil,
      created_at: DateTime.utc_now(),
      application: Sportipedia.Catalog,
      state: nil
    }

    assert :ok = WidgetProjector.handle(event, metadata)

    assert Repo.get(WidgetReadModel, event.id) != nil
  end
end
end
