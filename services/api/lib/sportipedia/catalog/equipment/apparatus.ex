defmodule Sportipedia.Catalog.Equipment.Apparatus do
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus

  def catalog_apparatus(params) do
    id = UUID.uuid4()
    cmd = CatalogApparatus.new(Map.put(params, :id, id))

    with :ok <- Sportipedia.Catalog.dispatch(cmd, consistency: :strong) do
      {:ok, ApparatusInternal.apparatus_by_id(id)}
    end
  end
end
