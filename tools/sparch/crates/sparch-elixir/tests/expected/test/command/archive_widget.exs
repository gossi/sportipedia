defmodule Sportipedia.Catalog.Equipment.Widget.Operation.ArchiveWidgetTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget.Command.ArchiveWidget
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
end
