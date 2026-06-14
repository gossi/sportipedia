defmodule Sportipedia.Catalog.Equipment.Instrument do
  @moduledoc """
  Public API for managing instruments in the equipment catalog.
  """

  alias Sportipedia.Architecture
  alias Sportipedia.Catalog.Equipment.Instrument.Command.ArchiveInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.Command.CatalogInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.Command.EditInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentInternal
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  alias Sportipedia.Catalog.Repo
  alias Sportipedia.Support.ErrorClassifier
  alias Sportipedia.Support.JSONAPI.QueryBuilder

  @doc """
  Catalogs a new instrument. Returns the created instrument.
  """
  @spec catalog_instrument(%{
          required(:title) => String.t(),
          required(:slug) => String.t(),
          optional(:description) => String.t() | nil
        }) :: Architecture.public_api(InstrumentReadModel.t())
  def catalog_instrument(params) do
    id = UUID.uuid4()
    cmd = CatalogInstrument.new(Map.put(params, :id, id))

    case Sportipedia.Catalog.dispatch(cmd, consistency: :strong) do
      :ok ->
        {:ok, InstrumentInternal.instrument_by_id(id)}

      {:error, errors} ->
        ErrorClassifier.classify_error(errors)
    end
  end

  @doc """
  Edits an existing instrument. Returns the updated instrument.
  """
  @spec edit_instrument(%{
          required(:id) => String.t(),
          optional(:title) => String.t() | nil,
          optional(:slug) => String.t() | nil,
          optional(:description) => String.t() | nil
        }) :: Architecture.public_api(InstrumentReadModel.t())
  def edit_instrument(params) do
    cmd = EditInstrument.new(params)

    case Sportipedia.Catalog.dispatch(cmd, consistency: :strong) do
      :ok ->
        {:ok, InstrumentInternal.instrument_by_id(params["id"])}

      {:error, errors} ->
        ErrorClassifier.classify_error(errors)
    end
  end

  @doc """
  Archives an existing instrument. Returns :ok on success.
  """
  @spec archive_instrument(String.t()) :: Architecture.public_api()
  def archive_instrument(id) do
    case Sportipedia.Catalog.dispatch(ArchiveInstrument.new(id: id), consistency: :strong) do
      :ok -> :ok
      {:error, errors} -> ErrorClassifier.classify_error(errors)
    end
  end

  @doc """
  Fetches an instrument by its ID. Returns nil if not found.
  """
  @spec instrument_by_id(String.t()) :: InstrumentReadModel.t() | nil
  def instrument_by_id(id) do
    InstrumentInternal.instrument_by_id(id)
  end

  @doc """
  Lists all instruments with filtering, sorting, and pagination.
  """
  @spec list_instruments(JSONAPI.Config.t()) :: Architecture.public_api([InstrumentReadModel.t()])
  def list_instruments(query) do
    {:ok, Repo.all(QueryBuilder.build(query, InstrumentReadModel))}
  end

  @doc """
  Reads a single instrument by its id or slug. Returns the instrument or not_found.
  """
  @spec read_instrument(%{required(:id) => String.t()} | %{required(:slug) => String.t()}) ::
          {:ok, InstrumentReadModel.t()} | {:error, :not_found}
  def read_instrument(%{id: id}) do
    case InstrumentInternal.instrument_by_id(id) do
      nil -> {:error, :not_found}
      instrument -> {:ok, instrument}
    end
  end

  def read_instrument(%{slug: slug}) do
    case InstrumentInternal.instrument_by_slug(slug) do
      nil -> {:error, :not_found}
      instrument -> {:ok, instrument}
    end
  end
end
