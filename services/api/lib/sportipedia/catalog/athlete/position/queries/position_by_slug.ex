defmodule Sportipedia.Catalog.Athlete.Position.Queries.PositionBySlug do
  @moduledoc """
  Query to fetch a position by its slug.
  """

  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  import Ecto.Query

  @doc """
  Creates a new query to fetch a position by slug.
  """
  def new(slug) do
    from(r in PositionReadModel,
      where: r.slug == ^slug
    )
  end
end
