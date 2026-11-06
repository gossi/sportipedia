defmodule Sportipedia.Catalog.Athlete.Position.Validators.InstrumentExists do
  @moduledoc """
  Validates the 'equipment-exists' rule: If apparatusId or instrumentId is
  provided, the referenced equipment must exist. This is the instrument side of
  that rule.

  The check crosses a constituent boundary, so it asks the equipment
  constituent's public API — never its internal API and never the `Repo`. It
  returns the same `:equipment_not_found` as the apparatus validator
  (`ApparatusExists`): the rule is about the equipment, not about which kind of
  equipment. See
  `docs/architecture/blueprints/backend/domain/examples/domain-object-exists.md`.
  """
  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Instrument

  @doc """
  Validates that the given instrument id references an existing instrument.
  """
  @spec validate(String.t(), map()) :: :ok | {:error, :equipment_not_found}
  def validate(instrument_id, _context) do
    case Instrument.read_instrument(instrument_id) do
      {:ok, _instrument} -> :ok
      {:error, :not_found} -> {:error, :equipment_not_found}
    end
  end
end
