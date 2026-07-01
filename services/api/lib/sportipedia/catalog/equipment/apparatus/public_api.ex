defmodule Sportipedia.Catalog.Equipment.Apparatus do
  @moduledoc """
  Public API for managing apparatuses in the sport equipment catalog.
  """

  alias Sportipedia.Support.ErrorClassifier
  alias Sportipedia.Architecture
  alias Sportipedia.Catalog
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.ArchiveApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.CatalogApparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.Command.EditApparatus
  alias Sportipedia.Catalog.Repo
  alias Sportipedia.Support.JSONAPI.QueryBuilder

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
    cmd = CatalogApparatus.new(Map.put(params, "id", id))

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
    case Catalog.dispatch(EditApparatus.new(params), consistency: :strong) do
      :ok ->
        id = params[:id] || params["id"]
        {:ok, ApparatusInternal.apparatus_by_id(id)}

      {:error, errors} ->
        ErrorClassifier.classify_error(errors)
    end
  end

  @doc """
  Archives an apparatus. Returns :ok on success.
  """
  @spec archive_apparatus(String.t()) :: Architecture.public_api()
  def archive_apparatus(id) do
    case Catalog.dispatch(ArchiveApparatus.new(id: id), consistency: :strong) do
      :ok -> :ok
      {:error, errors} -> ErrorClassifier.classify_error(errors)
    end
  end

  @doc """
  Reads a single apparatus by its id or slug. Returns the apparatus or :not_found.
  """
  @spec read_apparatus(String.t()) :: Architecture.public_api(ApparatusReadModel.t())
  def read_apparatus(id_or_slug) do
    case lookup_apparatus(id_or_slug) do
      nil -> {:error, :not_found}
      read_model -> {:ok, read_model}
    end
  end

  defp lookup_apparatus(id_or_slug) do
    if uuid?(id_or_slug) do
      ApparatusInternal.apparatus_by_id(id_or_slug)
    else
      ApparatusInternal.apparatus_by_slug(id_or_slug)
    end
  end

  defp uuid?(maybe_id) do
    case UUID.info(maybe_id) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Lists all apparatuses with optional filtering, sorting, and pagination.
  """
  @spec list_apparatuses(JSONAPI.Config.t()) :: Architecture.public_api([ApparatusReadModel.t()])
  def list_apparatuses(query) do
    {:ok, Repo.all(QueryBuilder.build(query, ApparatusReadModel))}
  end
end
