defmodule Sportipedia.Catalog.Athlete.Position.Queries.PositionBySlug do
  @moduledoc """
  Query to fetch a position by its slug.
  """

  import Ecto.Query

  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel

  @doc """
  Creates a new query to fetch a position by slug.
  """
  @spec new(String.t()) :: Ecto.Query.t()
  def new(slug) do
    from(r in PositionReadModel,
      where: r.slug == ^slug
    )
  end
end
