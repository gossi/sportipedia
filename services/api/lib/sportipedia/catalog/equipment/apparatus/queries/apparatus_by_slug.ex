defmodule Sportipedia.Catalog.Equipment.Apparatus.Queries.ApparatusBySlug do
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  import Ecto.Query

  def new(slug) do
    from(r in ApparatusReadModel,
      where: r.slug == ^slug
    )
  end
end
