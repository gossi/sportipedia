defmodule Sportipedia.Catalog.Equipment.Apparatus.Queries.ApparatusBySlug do
  @moduledoc """
  Query to fetch an apparatus by its slug.
  """

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  import Ecto.Query

  @doc """
  Creates a new query to fetch an apparatus by slug.
  """
  @spec new(String.t()) :: Ecto.Query.t()
  def new(slug) do
    from(r in ApparatusReadModel,
      where: r.slug == ^slug
    )
  end
end
