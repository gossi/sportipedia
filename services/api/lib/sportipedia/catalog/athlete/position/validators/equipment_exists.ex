defmodule Sportipedia.Catalog.Athlete.Position.Validators.EquipmentExists do
  @moduledoc """
  Validates the 'equipment-exists' rule: If apparatusId or instrumentId is provided, the referenced equipment must exist
  """
  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusInternal
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentInternal

  @doc """
  Validates the given apparatusId value.
  """
  @spec validate(String.t(), map()) :: :ok | {:error, term()}
  def validate(apparatusId, context) do
    with :ok <- check_apparatus(apparatusId),
         :ok <- check_instrument(Map.get(context, :instrumentId)) do
      :ok
    end
  end

  # both references are optional: only a provided id has to resolve
  defp check_apparatus(nil), do: :ok

  defp check_apparatus(id) do
    case ApparatusInternal.apparatus_by_id(id) do
      nil -> {:error, :apparatus_not_found}
      _apparatus -> :ok
    end
  end

  defp check_instrument(nil), do: :ok

  defp check_instrument(id) do
    case InstrumentInternal.instrument_by_id(id) do
      nil -> {:error, :instrument_not_found}
      _instrument -> :ok
    end
  end
end
