defmodule Sportipedia.Catalog.Equipment.Widget.Operation.NoteWidgetTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget
alias Sportipedia.Catalog.Equipment.Widget.Command.NoteWidget
alias Sportipedia.Catalog.Equipment.Widget.Command.NoteWidgetHandler
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetNoted
alias Sportipedia.Catalog.Equipment.Widget.Policy
alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate
@moduletag :integration
describe "Command" do
  test "requires id" do
    assert_raise ArgumentError, fn ->
      struct!(NoteWidget, %{})
    end
  end

  test "id cannot be nil" do
    cmd = %NoteWidget{comment: "sample-comment", id: nil}

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

  test "validates presence of comment" do
    cmd = %NoteWidget{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), comment: nil}

    assert {:error, _errors} = Vex.validate(cmd)
  end
end
describe "Command Handler" do
  test "handles NoteWidget command and returns WidgetNoted event" do
    cmd = %NoteWidget{id: UUID.uuid5(:dns, "equipment:widget:classic-widget"), comment: "sample-comment"}

    events = NoteWidgetHandler.handle(%WidgetAggregate{}, cmd)

    assert %WidgetNoted{} = events
  end
end
describe "Policy" do
  test "denies or allows guests for note_widget" do
    assert Policy.authorize(:note_widget, nil, %{}) == :error
  end

  test "allows users for note_widget" do
    assert Policy.authorize(:note_widget, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
  end
end
describe "Public API" do
  test "note_widget succeeds" do
    assert :ok = Widget.note_widget(%{comment: "sample-comment"})
  end

  test "note_widget returns validation errors" do
    assert {:error, {:validation_failure, _errors}} = Widget.note_widget(%{})
  end
end
end
