defmodule Sportipedia.Catalog.Equipment.Apparatus do
  alias Sportipedia.Catalog
  alias Sportipedia.Catalog.Repo
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus

  def apparatus_by_id(id) when is_binary(id) do
    Repo.get(ApparatusReadModel, id)
  end

  # def apparatus_by_id!(id) when is_binary(id) do
  #   Repo.get!(ApparatusReadModel, id)
  # end

  def catalog_apparatus(params) do
    id = UUID.uuid4()
    cmd = CatalogApparatus.new(Map.put(params, :id, id))

    with {:ok, _aggregate} <-
           Catalog.dispatch(cmd, consistency: :strong, include_aggregate_version: true) do
      {:ok, apparatus_by_id(id)}
    end
  end
end
