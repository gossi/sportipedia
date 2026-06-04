defmodule Sportipedia.Catalog.Equipment.Apparatus.Queries.ApparatusBySlug do
  import Ecto.Query

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel

  def new(slug) do
    from(r in ApparatusReadModel,
      where: r.slug == ^slug
    )
  end
end
