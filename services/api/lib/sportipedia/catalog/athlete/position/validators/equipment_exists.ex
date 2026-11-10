defmodule Sportipedia.Catalog.Athlete.Position.Validators.EquipmentExists do
  @moduledoc """
  Validates the 'equipment-exists' rule: If apparatusId or instrumentId is provided, the referenced equipment must exist.

  A cross-aggregate reference rule, so its verdict is its own atom — never
  `:not_found`, which `Sportipedia.Support.ErrorClassifier` would collapse into a
  whole-command 404 for a request that created nothing.

  A legal reference is an id, never a slug, and the read goes through the
  referenced constituent's public API: this is a boundary the position slice may
  not reach past, so it asks the equipment's port, not its store.
  """
  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Instrument
  alias Sportipedia.Support.Validators.UuidValidator

  @doc """
  Validates the given equipment reference, whichever of the two reference fields
  supplied it.
  """
  # `term()`, not `String.t()`: the value reaches here straight off the request,
  # and a request can name an equipment with anything at all.
  @spec validate(term(), map()) :: :ok | {:error, :equipment_not_found}
  def validate(reference, context) do
    # The lookup would raise on a value the `:binary_id` column cannot hold, and
    # a raise in a validator reaches the client as a 500. A value that cannot
    # denote an equipment denotes no equipment: the rule's own verdict, given
    # without touching the store.
    if UuidValidator.valid_uuid?(reference) do
      equipment_verdict(reference, context)
    else
      {:error, :equipment_not_found}
    end
  end

  # The generator registers this one validator on both reference fields, and Vex
  # hands a validator its value, not the field it was read from — so the
  # command's own references are what say which kind of equipment the value
  # names: one lookup for the supplied id, through that constituent's port.
  defp equipment_verdict(reference, context) do
    cond do
      reference == Map.get(context, :apparatusId) ->
        verdict(Apparatus.read_apparatus(reference))

      reference == Map.get(context, :instrumentId) ->
        verdict(Instrument.read_instrument(reference))

      # Named by neither reference: there is no equipment kind to ask about.
      true ->
        :ok
    end
  end

  defp verdict({:ok, _equipment}), do: :ok
  defp verdict(_equipment_not_found), do: {:error, :equipment_not_found}
end
