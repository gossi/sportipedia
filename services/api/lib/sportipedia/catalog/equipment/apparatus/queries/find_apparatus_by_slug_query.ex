defmodule Sportipedia.Catalog.Equipment.Apparatus.Queries.FindApparatusBySlugQuery do
  import Ecto.Query

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel

  def new(slug) do
    from a in ApparatusReadModel,
      where: a.slug == ^slug
  end
end
