defmodule Sportipedia.Catalog.Equipment.Apparatus do
  alias Sportipedia.Catalog
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal

  def catalog_apparatus(params) do
    params = Map.put_new(params, :id, UUID.uuid4())

    with {:ok, _aggregate} <- Catalog.dispatch(CatalogApparatus.new(params), consistency: :strong, include_aggregate_version: true) do
      slug = (params[:slug] || params["slug"]) |> String.downcase()

      case ApparatusInternal.apparatus_by_slug(slug) do
        nil -> {:error, :not_found}
        apparatus -> {:ok, apparatus}
      end
    end
  end
end
