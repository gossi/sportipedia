defmodule Sportipedia.Catalog.Equipment.Apparatus.Queries.ListApparatuses do
  @moduledoc """
  List all apparatus with filtering, sorting, and pagination
  """
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Support.JSONAPI.QueryBuilder

  @doc """
  Creates a new query to fetch apparatuses.
  """
  @spec new(JSONAPI.Config.t()) :: Ecto.Query.t()
  def new(query) do
    QueryBuilder.build(query, ApparatusReadModel)
  end
end
