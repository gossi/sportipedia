defmodule SportipediaWeb.Catalog.Equipment.ApparatusView do
  use JSONAPI.View, type: "apparatuses"

  def path, do: "catalog/equipment/apparatuses"

  def fields, do: [:id, :title, :slug, :description]
end
