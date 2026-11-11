defmodule SportipediaWeb.Catalog.Athlete.Position.PositionView do
  @moduledoc """
  Renders position resources in JSON:API format.

  The position's public slug is its canonical path
  (`<equipment-slug>/<raw-slug>` when bound, the bare raw slug when unbound);
  the raw slug the command supplied is stored as `raw_slug` and stays out of
  the representation.
  """
  use JSONAPI.View, type: "position"
  def path, do: "catalog/athlete/positions"
  def fields, do: [:title, :slug, :apparatusId, :description, :instrumentId]
end
