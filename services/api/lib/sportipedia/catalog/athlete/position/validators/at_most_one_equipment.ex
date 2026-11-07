defmodule Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment do
  @moduledoc """
  Validates the 'at-most-one-equipment' rule: A position can reference at most
  one piece of equipment (either apparatusId or instrumentId, not both).

  The value it is called with is irrelevant — the rule compares two fields of
  the context. Any map carrying `:apparatusId` and `:instrumentId` can be checked.

  This judges the command **as supplied**: it is the early rejection of a
  request that names both kinds at once, on the field the rule is attached to.
  An edit's *effective* state — the patch merged over what the position holds —
  is the aggregate invariant's other half, and it belongs to
  `Sportipedia.Catalog.Athlete.Position.Command.EditPositionHandler`: the
  handler sees the state its own stream built, serialized, with nothing to read
  from the projection and no window between reading and writing.
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
