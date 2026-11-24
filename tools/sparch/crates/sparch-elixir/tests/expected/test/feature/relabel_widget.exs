defmodule Sportipedia.Catalog.Equipment.Widget.Operation.RelabelWidgetTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget
alias Sportipedia.Catalog.Equipment.Widget.Command.RelabelWidget
alias Sportipedia.Catalog.Equipment.Widget.Command.RelabelWidgetHandler
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetRelabelled
alias Sportipedia.Catalog.Equipment.Widget.Policy
alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate
@moduletag :integration
describe "Command" do
  test "requires id" do
    assert_raise ArgumentError, fn ->
      struct!(RelabelWidget, %{})
    end
  end

  test "id cannot be nil" do
    cmd = %RelabelWidget{label: "classic", id: nil}

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

  test "validates presence of label" do
    cmd = %RelabelWidget{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), label: nil}

    assert {:error, _errors} = Vex.validate(cmd)
  end
end
describe "Command Handler" do
  test "handles RelabelWidget command and returns WidgetRelabelled event" do
    cmd = %RelabelWidget{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), label: "classic"}

    events = RelabelWidgetHandler.handle(%WidgetAggregate{}, cmd)

    assert %WidgetRelabelled{} = events
  end
end
describe "Policy" do
  test "denies or allows guests for relabel_widget" do
    assert Policy.authorize(:relabel_widget, nil, %{}) == :error
  end

  test "allows users for relabel_widget" do
    assert Policy.authorize(:relabel_widget, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
  end
end
describe "Public API" do
  test "relabel_widget succeeds" do
    assert {:ok, created} = Widget.create_widget(%{title: "Classic Widget", slug: "classic-widget"})

    assert {:ok, read_model} = Widget.relabel_widget(%{id: created.id})

    assert read_model.id == created.id
  end
end
end
