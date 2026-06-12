defmodule Sportipedia.Catalog.Equipment.Apparatus do
  @moduledoc """
  Public API for managing apparatuses in the sport equipment catalog.
  """

  alias Sportipedia.Architecture
  alias Sportipedia.Catalog
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus

  @doc """
  Catalogs a new apparatus. Returns the created apparatus.
  """
  @spec catalog_apparatus(%{
          required(:title) => String.t(),
          required(:slug) => String.t(),
          optional(:description) => String.t() | nil
        }) :: Architecture.public_api(ApparatusReadModel.t())
  def catalog_apparatus(params) do
    id = UUID.uuid4()
    cmd = CatalogApparatus.new(Map.put(params, :id, id))

    with :ok <- Catalog.dispatch(cmd, consistency: :strong) do
      {:ok, ApparatusInternal.apparatus_by_id(id)}
    end
  end

  @doc """
  Edits an existing apparatus. Returns the updated apparatus.
  """
  @spec edit_apparatus(%{
          required(:id) => String.t(),
          optional(:title) => String.t() | nil,
          optional(:slug) => String.t() | nil,
          optional(:description) => String.t() | nil
        }) :: Architecture.public_api(ApparatusReadModel.t())
  def edit_apparatus(params) do
    id = params[:id] || params["id"]
    cmd = EditApparatus.new(params)

    with :ok <- Catalog.dispatch(cmd, consistency: :strong) do
      {:ok, ApparatusInternal.apparatus_by_id(id)}
    end
  end
end
