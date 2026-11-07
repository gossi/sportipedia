defmodule Sportipedia.Catalog.Athlete.Position.Queries.ListPositions do
  @moduledoc """
  Retrieve a single position by its id or slug
  """

  alias Sportipedia.Support.JSONAPI.QueryBuilder
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel

  @doc """
  Creates a query that fetches the single position addressed by an id or a slug:
  the parameter is taken as the position's `id` when it is a UUID and as its
  `slug` otherwise.
  """
  @spec new(JSONAPI.Config.t()) :: Ecto.Query.t()
  def new(query) do
    QueryBuilder.build(query, PositionReadModel)
  end
end
