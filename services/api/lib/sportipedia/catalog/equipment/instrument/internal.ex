defmodule Sportipedia.Catalog.Equipment.Instrument.InstrumentInternal do
  @moduledoc """
  Internal API for querying instrument read models within the bounded context.
  """

  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  alias Sportipedia.Catalog.Equipment.Instrument.Queries.InstrumentBySlug
  alias Sportipedia.Catalog.Repo

  @doc """
  Fetches an instrument by its ID. Returns nil if not found.
  """
  @spec instrument_by_id(String.t()) :: InstrumentReadModel.t() | nil
  def instrument_by_id(id) do
    Repo.get(InstrumentReadModel, id)
  end

  @doc """
  Fetches an instrument by its slug. Returns nil if not found.
  """
  @spec instrument_by_slug(String.t()) :: InstrumentReadModel.t() | nil
  def instrument_by_slug(slug) do
    slug
    |> String.downcase()
    |> InstrumentBySlug.new()
    |> Repo.one()
  end
end
