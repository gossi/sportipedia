defmodule Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment do
  @moduledoc """
  Validates the 'at-most-one-equipment' rule: A position can reference at most
  one piece of equipment (either apparatusId or instrumentId, not both).

  The value it is called with is irrelevant — the rule compares two fields of
  the command, so it reads them off the context. Any map carrying `:apparatusId`
  and `:instrumentId` can be checked.

  That also makes this validator the single place the rule is stated:
  `EditPositionHandler` calls it with the command's fields merged over the loaded
  aggregate state, where a patch that supplies one side while the stored position
  holds the other would otherwise go unnoticed.
  """

  use Vex.Validator

  @doc """
  Rejects a state that carries both equipment references.
  """
  @spec validate(term(), map()) :: :ok | {:error, :at_most_one_equipment}
  def validate(_value, context) do
    case {Map.get(context, :apparatusId), Map.get(context, :instrumentId)} do
      {nil, _} -> :ok
      {_, nil} -> :ok
      _ -> {:error, :at_most_one_equipment}
    end
  end
end
