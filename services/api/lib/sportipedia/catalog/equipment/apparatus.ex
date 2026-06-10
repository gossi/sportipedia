defmodule Sportipedia.Catalog.Equipment.Apparatus do
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus

  def catalog_apparatus(params) do
    id = UUID.uuid4()
    cmd = CatalogApparatus.new(Map.put(params, :id, id))

    with :ok <- Sportipedia.Catalog.dispatch(cmd, consistency: :strong) do
      {:ok, ApparatusInternal.apparatus_by_id(id)}
    end
  end

  def edit_apparatus(params) do
    cmd = EditApparatus.new(params)

    case Sportipedia.Catalog.dispatch(cmd, consistency: :strong) do
      :ok -> {:ok, ApparatusInternal.apparatus_by_id(cmd.id)}
      {:error, :apparatus_not_found} -> {:error, :notfound}
      error -> error
    end
  end
end
