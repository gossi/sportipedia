defmodule Sportipedia.Catalog.Equipment.Instrument do
  @moduledoc """
  Public API for managing instruments in the equipment catalog.
  """

  alias Sportipedia.Architecture
  alias Sportipedia.Catalog.Equipment.Instrument.Command.CatalogInstrument
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentInternal
  alias Sportipedia.Support.ErrorClassifier

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
end
