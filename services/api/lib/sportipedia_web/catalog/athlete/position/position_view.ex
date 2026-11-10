defmodule SportipediaWeb.Catalog.Athlete.Position.PositionView do
  @moduledoc """
  Renders position resources in JSON:API format.
  """
  use JSONAPI.View, type: "position"
  def path, do: "catalog/athlete/positions"
  def fields, do: [:title, :slug, :apparatusId, :description, :instrumentId]

  @doc """
  The position's public slug is its canonical lookup path
  (`<equipment-slug>/<slug>` when bound, the bare slug when unbound),
  not the raw slug the command supplied.
  """
  def slug(%{lookup_slug: lookup_slug}, _conn), do: lookup_slug
end
