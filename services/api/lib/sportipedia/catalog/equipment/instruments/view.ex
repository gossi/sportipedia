defmodule Sportipedia.Catalog.Equipment.Instruments.Views.InstrumentView do
  use JSONAPI.View, type: "instruments"

  def path, do: "catalog/equipment/instruments"

  def fields, do: [:title, :description, :slug]
end
