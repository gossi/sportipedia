defmodule Sportipedia.Catalog.Equipment.Widget.Event.WidgetEditedTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetEdited
alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate
alias Sportipedia.Catalog.Equipment.Widget.WidgetProjector
alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel
@moduletag :integration
describe "Event" do
  test "creates WidgetEdited with required fields" do
    event = struct!(WidgetEdited, %{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), description: "The original widget of the fixture world", label: "classic", slug: "classic-widget", title: "Classic Widget"})

    assert event.id != nil
  end

  test "requires enforced fields" do
    assert_raise ArgumentError, fn ->
      struct!(WidgetEdited, %{})
    end
  end

  test "serializes to JSON" do
    event = struct!(WidgetEdited, %{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), description: "The original widget of the fixture world", label: "classic", slug: "classic-widget", title: "Classic Widget"})

    assert {:ok, _json} = Jason.encode(event)
  end
end
describe "Aggregate" do
  test "applies widget-edited to aggregate state" do
    event = %WidgetEdited{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), description: "The original widget of the fixture world", label: "classic", slug: "classic-widget", title: "Classic Widget"}

    result = WidgetAggregate.apply(%WidgetAggregate{id: event.id}, event)

  assert result.id == event.id
        assert result.description == event.description
        assert result.label == event.label
        assert result.slug == event.slug
        assert result.title == event.title
  end
end
describe "Projector" do
  test "projects WidgetEdited to the widget read model" do
    create_event = %WidgetCreated{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), title: "Classic Widget", slug: "classic-widget", coach_id: UUID.uuid5(:dns, "equipment:coach:head-coach"), description: "The original widget of the fixture world", label: "classic", team_id: UUID.uuid5(:dns, "equipment:team:first-team")}

    create_metadata = %{
      handler_name: "equipment.widget_projection",
      event_number: 1,
      event_id: UUID.uuid4(),
      stream_id: "widget-#{create_event.id}",
      stream_version: 1,
      correlation_id: nil,
      causation_id: nil,
      created_at: DateTime.utc_now(),
      application: Sportipedia.Catalog,
      state: nil
    }
    assert :ok = WidgetProjector.handle(create_event, create_metadata)

    event = %WidgetEdited{id: create_event.id, description: "The original widget of the fixture world", label: "classic", slug: "classic-widget", title: "Classic Widget"}

    metadata = %{
      handler_name: "equipment.widget_projection",
      event_number: 2,
      event_id: UUID.uuid4(),
      stream_id: "widget-#{event.id}",
      stream_version: 2,
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
