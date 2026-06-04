defmodule Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal do
  alias Sportipedia.Catalog.Repo
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.Queries.ApparatusBySlug

  def apparatus_by_id(id) do
    Repo.get(ApparatusReadModel, id)
  end

  def apparatus_by_id!(id) do
    Repo.get!(ApparatusReadModel, id)
  end

  def apparatus_by_slug(slug) do
    slug
    |> String.downcase()
    |> ApparatusBySlug.new()
    |> Repo.one()
  end
end
