defmodule Sportipedia.Catalog.Athlete.Position.Queries.ReadPosition do
  @moduledoc """
  Retrieve a single position by its id or slug
  """
  @doc """
  Creates a new query to fetch positions.
  """
  @spec new(String.t()) :: Ecto.Query.t()
  def new(_params) do
    # TODO: construct and return the query from the read model
    raise "TODO: implement read-position query (see the feature spec)"
  end
end
