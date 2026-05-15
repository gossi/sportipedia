defmodule Sportipedia.Catalog.Equipment.Instruments do
  alias Sportipedia.Catalog.Equipment.Instruments.Command.EditInstrument
  alias Sportipedia.Catalog.Equipment.Instruments.Command.ArchiveInstrument
  alias Sportipedia.Support.JSONAPI.QueryBuilder
  alias Sportipedia.Catalog
  alias Sportipedia.Catalog.Repo
  alias Sportipedia.Catalog.Equipment.Instruments.InstrumentReadModel
  alias Sportipedia.Catalog.Equipment.Instruments.Command.CatalogInstrument
  alias Sportipedia.Catalog.Equipment.Instruments.Queries.InstrumentBySlug

  def instrument_by_id(id) when is_binary(id) do
    Repo.get(Instrument, id)
  end

  def instrument_by_id!(id) when is_binary(id) do
    Repo.get!(Instrument, id)
  end

  def instrument_by_slug(slug) do
    slug
    |> String.downcase()
    |> InstrumentBySlug.new()
    |> Repo.one()
  end

  def catalog_instrument(params) do
    id = UUID.uuid4()
    cmd = CatalogInstrument.new(Map.put(params, :id, id))

    with {:ok, aggregate} <-
           Catalog.dispatch(cmd, consistency: :strong, include_aggregate_version: true) do
      {:ok, instrument_by_id(id)}
    end
  end

  def edit_instrument(params) do
    with :ok <- Catalog.dispatch(EditInstrument.new(params), consistency: :strong) do
      {:ok, instrument_by_id(params["id"])}
    end
  end

  def read_instrument(id) do
    instrument_by_id(id)
  end

  def list_instruments(query) do
    Repo.all(QueryBuilder.build(query, Instrument))
  end

  def archive_instrument(id) do
    Catalog.dispatch(ArchiveInstrument.new(id: id), consistency: :strong)
  end
end
