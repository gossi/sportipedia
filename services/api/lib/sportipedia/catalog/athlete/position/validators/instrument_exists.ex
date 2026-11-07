defmodule Sportipedia.Catalog.Athlete.Position.Validators.InstrumentExists do
  @moduledoc """
  Validates the 'equipment-exists' rule for the instrument: If instrumentId is
  provided, the referenced equipment must exist

  A cross-aggregate reference rule: existence is read through the apparatus and
  instrument public APIs, never through the repo. A value that cannot denote an
  id (anything that is not a UUID — a legal reference is an id, never a slug)
  denotes no equipment. One atom for both kinds of equipment:
  `{:error, :equipment_not_found}`.
  """
  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Instrument
  alias Sportipedia.Support.Validators.UuidValidator

  @doc """
  Validates that the referenced apparatus exists (apparatusId clause).
  """
  @spec validate(term(), map()) :: :ok | {:error, :equipment_not_found}
  def validate(value, _context) do
    if UuidValidator.valid_uuid?(value) and instrument_exists?(value) do
      :ok
    else
      {:error, :equipment_not_found}
    end
  end

  defp instrument_exists?(id) do
    match?({:ok, _instrument}, Instrument.read_instrument(id))
  end
end
