defmodule Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment do
  @moduledoc """
  Validates the 'at-most-one-equipment' rule: A position can reference at most one piece of equipment (either apparatusId or instrumentId, not both)

  A cross-field rule: the two reference fields are its *addresses*, but the
  verdict comes from comparing both references the command carries, so the value
  handed to it is not read. It therefore takes no skip option — a pair on one of
  its fields would silence the rule exactly when the other field carries the
  second reference.
  """
  use Vex.Validator

  @doc """
  Validates the given equipment reference against the other reference the
  command carries.
  """
  @spec validate(term(), map()) :: :ok | {:error, :too_many_equipment}
  def validate(_reference, context) do
    if references_equipment?(Map.get(context, :apparatusId)) and
         references_equipment?(Map.get(context, :instrumentId)) do
      {:error, :too_many_equipment}
    else
      :ok
    end
  end

  # A blank reference names no equipment. Whether a reference is required at all
  # is the command's own line to say, not this rule's.
  defp references_equipment?(reference), do: reference not in [nil, ""]
end
