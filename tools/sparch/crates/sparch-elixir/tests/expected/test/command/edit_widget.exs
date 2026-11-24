defmodule Sportipedia.Catalog.Equipment.Widget.Operation.EditWidgetTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget.Command.EditWidget
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
end
