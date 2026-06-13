defmodule Sportipedia.Catalog.Equipment.Instrument.Validators.InstrumentExists do
  @moduledoc """
  Validates that an instrument exists.
  """

  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentInternal

  @doc """
  Validates the given id exists.
  """
  @spec validate(String.t() | nil, map()) :: :ok | {:error, :not_found}
  def validate(nil, _context), do: :ok

  def validate(id, _context) do
    case InstrumentInternal.instrument_by_id(id) do
      nil -> {:error, :not_found}
      _ -> :ok
    end
  end
end
