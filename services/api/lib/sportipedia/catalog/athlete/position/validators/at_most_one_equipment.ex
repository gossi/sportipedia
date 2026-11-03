defmodule Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment do
  @moduledoc """
  Validates the 'at-most-one-equipment' rule: A position can reference at most one piece of equipment (either apparatusId or instrumentId, not both)
  """
  use Vex.Validator

  @doc """
  Validates the given apparatusId value.
  """
  @spec validate(String.t(), map()) :: :ok | {:error, term()}
  def validate(apparatusId, context) do
    case {apparatusId, Map.get(context, :instrumentId)} do
      {nil, _} -> :ok
      {_, nil} -> :ok
      _ -> {:error, :too_many_equipment}
    end
  end
end
