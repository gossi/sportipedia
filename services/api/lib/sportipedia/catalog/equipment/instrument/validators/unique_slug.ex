defmodule Sportipedia.Catalog.Equipment.Instrument.Validators.UniqueSlug do
  @moduledoc """
  Validates that an instrument slug is unique within the catalog.
  """

  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentInternal

  @doc """
  Validates the given slug value for uniqueness.
  """
  @spec validate(String.t() | nil, map()) :: :ok | {:error, String.t()}
  def validate(nil, _context), do: :ok

  def validate(value, context) do
    with instrument when not is_nil(instrument) <-
           InstrumentInternal.instrument_by_slug(value),
         false <- slug_belongs_to_instrument?(instrument, context) do
      {:error, "slug already exists"}
    else
      _ -> :ok
    end
  end

  defp slug_belongs_to_instrument?(instrument, context) do
    id = Map.get(context, :id)

    id == instrument.id
  end
end
