defmodule Sportipedia.Catalog.Athlete.Position.Queries.ListPositions do
  @moduledoc """
  List all positions with filtering, sorting, and pagination
  """
  @doc """
  Creates a new query to fetch positions.
  """
  @spec new(map()) :: Ecto.Query.t()
  def new(_params) do
    # TODO: construct and return the query from the read model
    raise "TODO: implement list-positions query (see the feature spec)"
  end
end
