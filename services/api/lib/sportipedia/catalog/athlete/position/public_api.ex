defmodule Sportipedia.Catalog.Athlete.Position do
  @moduledoc """
  Public API for managing positions in the sport.
  """
  alias Sportipedia.Architecture
  alias Sportipedia.Catalog
  alias Sportipedia.Catalog.Athlete.Position.Command.ArchivePosition
  alias Sportipedia.Catalog.Athlete.Position.Command.CatalogPosition
  alias Sportipedia.Catalog.Athlete.Position.Command.EditPosition
  alias Sportipedia.Catalog.Athlete.Position.PositionInternal
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.Catalog.Athlete.Position.Queries.ListPositions
  alias Sportipedia.Catalog.Athlete.Position.Queries.ReadPosition
  alias Sportipedia.Catalog.Repo
  alias Sportipedia.Support.ErrorClassifier

  alias Sportipedia.Support.JSONAPI.QueryBuilder

  @doc """
  Catalogs a new position in the catalog: a body position or stance, optionally bound to one piece of equipment
  """
  @spec catalog_position(%{
          required(:title) => String.t(),
          required(:slug) => String.t(),
          optional(:apparatusId) => String.t() | nil,
          optional(:description) => String.t() | nil,
          optional(:instrumentId) => String.t() | nil
        }) :: Architecture.public_api(PositionReadModel.t())
  def catalog_position(params) do
    id = UUID.uuid4()
    cmd = CatalogPosition.new(Map.put(params, "id", id))

    case Catalog.dispatch(cmd, consistency: :strong) do
      :ok ->
        {:ok, PositionInternal.position_by_id(id)}

      {:error, errors} ->
        ErrorClassifier.classify_error(errors)
    end
  end

  @doc """
  Archives a position
  """
  @spec archive_position(String.t()) :: Architecture.public_api()
  def archive_position(id) do
    case Catalog.dispatch(ArchivePosition.new(id: id), consistency: :strong) do
      :ok -> :ok
      {:error, errors} -> ErrorClassifier.classify_error(errors)
    end
  end

  @doc """
  Edit properties of the position
  """
  @spec edit_position(%{
          required(:id) => String.t(),
          optional(:apparatusId) => String.t() | nil,
          optional(:description) => String.t() | nil,
          optional(:instrumentId) => String.t() | nil,
          optional(:slug) => String.t() | nil,
          optional(:title) => String.t() | nil
        }) :: Architecture.public_api(PositionReadModel.t())
  def edit_position(params) do
    case Catalog.dispatch(EditPosition.new(params), consistency: :strong) do
      :ok ->
        {:ok, PositionInternal.position_by_id(params[:id] || params["id"])}

      {:error, errors} ->
        ErrorClassifier.classify_error(errors)
    end
  end

  @doc """
  List all positions with filtering, sorting, and pagination
  """
  @spec list_positions(JSONAPI.Config.t()) :: Architecture.public_api([PositionReadModel.t()])
  def list_positions(query) do
    {:ok, Repo.all(QueryBuilder.build(query, ListPositions.new(query), PositionReadModel))}
  end

  @doc """
  Retrieve a single position by its id or slug
  """
  @spec read_position(String.t()) :: Architecture.public_api(PositionReadModel.t())
  def read_position(id_or_slug) do
    case Repo.one(ReadPosition.new(id_or_slug)) do
      nil -> {:error, :not_found}
      read_model -> {:ok, read_model}
    end
  end
end
