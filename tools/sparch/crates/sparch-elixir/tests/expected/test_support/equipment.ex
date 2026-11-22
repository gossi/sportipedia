defmodule Sportipedia.TestSupport.Catalog.Equipment do
@moduledoc """
Test-support factories for the equipment composite — they turn
fixtures (or plain attribute maps) into persisted read models.
Generated `new_*` units append per read model; the file is a ledger.
"""
alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel
alias Sportipedia.Catalog.Repo
@spec new_widget(WidgetReadModel.t() | map()) ::
        {:ok, WidgetReadModel.t()} | {:error, Ecto.Changeset.t()}
def new_widget(%WidgetReadModel{} = fixture) do
  new_widget(Map.from_struct(fixture))
end

def new_widget(attributes) when is_map(attributes) do
  %WidgetReadModel{}
  |> WidgetReadModel.insert_changeset(attributes)
  |> Repo.insert()
end
@spec new_widgets([WidgetReadModel.t() | map()]) :: [WidgetReadModel.t()]
def new_widgets(attribute_collection) do
  Enum.map(attribute_collection, fn attributes ->
    case new_widget(attributes) do
      {:ok, widget} -> widget
      {:error, changeset} ->
        raise "seeding widget fixture failed: #{inspect(changeset.errors)}"
    end
  end)
end
end
