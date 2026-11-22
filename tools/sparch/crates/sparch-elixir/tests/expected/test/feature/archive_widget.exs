defmodule Sportipedia.Catalog.Equipment.Widget.Operation.ArchiveWidgetTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget
alias Sportipedia.Catalog.Equipment.Widget.Command.ArchiveWidget
alias Sportipedia.Catalog.Equipment.Widget.Command.ArchiveWidgetHandler
alias Sportipedia.Catalog.Equipment.Widget.Event.WidgetArchived
alias Sportipedia.Catalog.Equipment.Widget.Policy
alias Sportipedia.Catalog.Equipment.Widget.WidgetAggregate
@moduletag :integration
describe "Command" do
  test "requires id" do
    assert_raise ArgumentError, fn ->
      struct!(ArchiveWidget, %{})
    end
  end

  test "id cannot be nil" do
    cmd = %ArchiveWidget{id: nil}

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
  test "handles ArchiveWidget command and returns WidgetArchived event" do
    cmd = %ArchiveWidget{id: UUID.uuid5(:dns, "equipment:widget:classic-widget")}

    events = ArchiveWidgetHandler.handle(%WidgetAggregate{}, cmd)

    assert %WidgetArchived{} = events
  end
end
describe "Policy" do
  test "denies or allows guests for archive_widget" do
    assert Policy.authorize(:archive_widget, nil, %{}) == :error
  end

  test "allows users for archive_widget" do
    assert Policy.authorize(:archive_widget, %{id: UUID.uuid4(), role: "user"}, %{}) == :ok
  end
end
describe "Public API" do
  test "archive_widget succeeds" do
    assert {:ok, created} = Widget.create_widget(%{title: "Classic Widget", slug: "classic-widget"})

    assert :ok = Widget.archive_widget(created.id)
  end

  test "archive_widget fails for an unknown widget" do
    assert {:error, _} = Widget.archive_widget(UUID.uuid4())
  end
end
end
