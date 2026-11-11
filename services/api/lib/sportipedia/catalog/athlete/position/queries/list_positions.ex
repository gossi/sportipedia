defmodule Sportipedia.Catalog.Athlete.Position.Queries.ListPositions do
  @moduledoc """
  List all positions with filtering, sorting, and pagination

  The collection is over the live read-model table: a position that left the
  catalog has no row to exclude.
  """

  alias Sportipedia.Support.JSONAPI.QueryBuilder
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel

  @doc """
  Creates a new query to fetch positions.
  """
  @spec new(JSONAPI.Config.t()) :: Ecto.Query.t()
  def new(query) do
    QueryBuilder.build(query, PositionReadModel)
  end
end
