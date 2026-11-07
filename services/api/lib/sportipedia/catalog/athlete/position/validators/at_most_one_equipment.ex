defmodule Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment do
  @moduledoc """
  Validates the 'at-most-one-equipment' rule: A position can reference at most
  one piece of equipment (either apparatusId or instrumentId, not both)

  A cross-field rule: it addresses a field but ignores its value, comparing the
  `apparatusId` and `instrumentId` of the command instead. The violated rule
  answers `{:error, :only_one_equipment_allowed}`.
  """
  use Vex.Validator

  @doc """
  Validates that the command references at most one piece of equipment.
  Called with either equipment field as address; the value is not inspected.
  """
  @spec validate(term(), map()) :: :ok | {:error, :only_one_equipment_allowed}
  def validate(_value, context) do
    if is_nil(context.apparatusId) or is_nil(context.instrumentId) do
      :ok
    else
      {:error, :only_one_equipment_allowed}
    end
  end
end
