defmodule SportipediaWeb.Catalog.Athlete.Position.PositionView do
  @moduledoc """
  Renders position resources in JSON:API format.
  """
  use JSONAPI.View, type: "position"
  def path, do: "catalog/athlete/positions"
  def fields, do: [:title, :slug, :apparatusId, :archivedAt, :description, :instrumentId]
end
