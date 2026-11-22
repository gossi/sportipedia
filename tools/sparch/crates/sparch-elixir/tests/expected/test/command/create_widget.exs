defmodule Sportipedia.Catalog.Equipment.Widget.Operation.CreateWidgetTest do
use Sportipedia.CatalogTestCase
alias Sportipedia.Catalog.Equipment.Widget.Command.CreateWidget
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
end
