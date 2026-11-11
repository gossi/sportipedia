defmodule Sportipedia.Catalog.Equipment.Instrument.Queries.ListInstruments do
  @moduledoc """
  List all instruments with filtering, sorting, and pagination
  """
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  alias Sportipedia.Support.JSONAPI.QueryBuilder

  @doc """
  Creates a new query to fetch instruments.
  """
  @spec new(JSONAPI.Config.t()) :: Ecto.Query.t()
  def new(query) do
    QueryBuilder.build(query, InstrumentReadModel)
  end
end
