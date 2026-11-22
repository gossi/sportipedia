defmodule Sportipedia.Catalog.Equipment.Widget.Operation.CreateWidgetTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget
alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget
alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidgetHandler
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetCreated
alias Sportipedia.Catalog.Equipment.Widget.Policy
alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate
@moduletag :integration
describe "Command" do
  test "requires id" do
    assert_raise ArgumentError, fn ->
      struct!(CreateWidget, %{})
    end
  end

  test "validates presence of title" do
    cmd = %CreateWidget{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), slug: "pommel-horse", coach_id: UUID.uuid5(:dns, "equipment:coach:head-coach"), description: "The original widget of the fixture world", label: "Pommel", team_id: UUID.uuid5(:dns, "equipment:team:first-team"), title: nil}

    assert {:error, _errors} = Vex.validate(cmd)
  end

  test "validates presence of slug" do
    cmd = %CreateWidget{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), title: "Pommel Horse", coach_id: UUID.uuid5(:dns, "equipment:coach:head-coach"), description: "The original widget of the fixture world", label: "Pommel", team_id: UUID.uuid5(:dns, "equipment:team:first-team"), slug: nil}

    assert {:error, _errors} = Vex.validate(cmd)
  end
end
describe "Command Handler" do
  test "handles CreateWidget command and returns WidgetCreated event" do
    cmd = %CreateWidget{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), title: "Pommel Horse", slug: "pommel-horse", coach_id: UUID.uuid5(:dns, "equipment:coach:head-coach"), description: "The original widget of the fixture world", label: "Pommel", team_id: UUID.uuid5(:dns, "equipment:team:first-team")}

    events = CreateWidgetHandler.handle(%WidgetAggregate{}, cmd)

    assert %WidgetCreated{} = events
  end
end
describe "Policy" do
  test "denies or allows guests for create_widget" do
    assert Policy.authorize(:create_widget, nil, %{}) == :error
  end

  test "allows users for create_widget" do
    assert Policy.authorize(:create_widget, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
  end
end
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
