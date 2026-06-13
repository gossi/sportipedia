defmodule SportipediaWeb.Catalog.Equipment.Instrument.InstrumentView do
  @moduledoc """
  Renders instrument resources in JSON:API format.
  """

  use JSONAPI.View, type: "instruments"

  @doc """
  Returns the path for instrument resources.
  """
  def path, do: "catalog/equipment/instruments"

  @doc """
  Returns the fields for rendering an instrument.
  """
  def fields do
    [
      :title,
      :slug,
      :description
    ]
  end
end
