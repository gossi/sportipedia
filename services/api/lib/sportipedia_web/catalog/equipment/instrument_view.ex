defmodule SportipediaWeb.Catalog.Equipment.InstrumentView do
  use JSONAPI.View, type: "instruments"

  def path, do: "catalog/equipment/instruments"

  def fields, do: [:title, :description, :slug]
end
