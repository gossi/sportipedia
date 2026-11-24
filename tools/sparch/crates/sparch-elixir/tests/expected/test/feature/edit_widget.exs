defmodule Sportipedia.Catalog.Equipment.Widget.Operation.EditWidgetTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget
alias Sportipedia.Catalog.Equipment.Widget.Command.EditWidget
alias Sportipedia.Catalog.Equipment.Widget.Command.EditWidgetHandler
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetEdited
alias Sportipedia.Catalog.Equipment.Widget.Policy
alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate
@moduletag :integration
describe "Command" do
  test "requires id" do
    assert_raise ArgumentError, fn ->
      struct!(EditWidget, %{})
    end
  end

  test "id cannot be nil" do
    cmd = %EditWidget{coach_id: UUID.uuid5(:dns, "equipment:coach:head-coach"), description: "The original widget of the fixture world", label: "Vaulting", slug: "vaulting-table", team_id: UUID.uuid5(:dns, "equipment:team:first-team"), title: "Vaulting Table", id: nil}

    # Rejected, not raised: the existence check used to hand the nil to
    # `Repo.get/2`, which raises, and the command never got to answer.
    # `allow_blank` on the `validates` line keeps the lookup off an absent
    # address, so `presence` is the only rule that speaks for the id.
    assert [:presence] ==
             cmd
             |> Vex.errors()
             |> Enum.flat_map(fn {_error, field, rule, _message} ->
               if field == :id, do: [rule], else: []
             end)
  end
end
describe "Command Handler" do
  test "handles EditWidget command and returns WidgetEdited event" do
    cmd = %EditWidget{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), coach_id: UUID.uuid5(:dns, "equipment:coach:head-coach"), description: "The original widget of the fixture world", label: "Vaulting", slug: "vaulting-table", team_id: UUID.uuid5(:dns, "equipment:team:first-team"), title: "Vaulting Table"}

    events = EditWidgetHandler.handle(%WidgetAggregate{}, cmd)

    assert %WidgetEdited{} = events
  end
end
describe "Policy" do
  test "denies or allows guests for edit_widget" do
    assert Policy.authorize(:edit_widget, nil, %{}) == :error
  end

  test "allows users for edit_widget" do
    assert Policy.authorize(:edit_widget, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
  end
end
describe "Public API" do
  test "edit_widget succeeds" do
    assert {:ok, created} = Widget.create_widget(%{title: "Vaulting Table", slug: "sample-slug-#{UUID.uuid4()}"})

    assert {:ok, read_model} = Widget.edit_widget(%{id: created.id})

    assert read_model.id == created.id
  end
end
end
