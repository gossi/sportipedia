defmodule Sportipedia.Catalog.Athlete.Position.Command.EditPositionHandler do
  @moduledoc """
  Handles the EditPosition command.
  """
  alias Sportipedia.Catalog.Athlete.Position.Command.EditPosition
  alias Sportipedia.Catalog.Athlete.Position.Event.PositionEdited
  alias Sportipedia.Catalog.Athlete.Position.PositionAggregate
  alias Sportipedia.Catalog.Athlete.Position.Validators.AtMostOneEquipment
  @behaviour Commanded.Commands.Handler

  @doc """
  Handles the EditPosition command and returns the PositionEdited event.

  An edit is a patch: a field the command does not carry keeps the value the
  aggregate holds — and a field carried as `nil` is not carried, because a JSON
  `null` and an absent attribute say the same thing to this handler. The event
  carries `id` plus only the changed fields. The invariant over the two equipment
  references is therefore decided on the merged state, not on the patch — a patch
  that supplies one side while the stored position holds the other would otherwise
  go unnoticed.
  """
  @spec handle(PositionAggregate.t(), EditPosition.t()) ::
          PositionEdited.t() | {:error, :at_most_one_equipment}
  def handle(%PositionAggregate{} = aggregate, %EditPosition{} = cmd) do
    changes = changed_fields(cmd)

    merged_state =
      aggregate
      |> Map.from_struct()
      |> Map.merge(changes)

    with :ok <- AtMostOneEquipment.validate(nil, merged_state) do
      struct!(%PositionEdited{id: cmd.id}, changes)
    end
  end

  defp changed_fields(%EditPosition{} = cmd) do
    cmd
    |> Map.from_struct()
    |> Map.drop([:id])
    |> Enum.reject(fn {_field, value} -> is_nil(value) end)
    |> Map.new()
  end
end
