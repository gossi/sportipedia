defmodule SportipediaWeb.Catalog.Equipment.Apparatus.ApparatusView do
  @moduledoc """
  Renders apparatus resources in JSON:API format.
  """

  use JSONAPI.View, type: "apparatuses"

  @doc """
  Returns the path for apparatus resources.
  """
  def path, do: "catalog/equipment/apparatuses"

  @doc """
  Returns the fields for rendering an apparatus.
  """
  def fields do
    [
      :title,
      :slug,
      :description
    ]
  end
end
