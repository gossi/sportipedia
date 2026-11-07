defmodule Sportipedia.Catalog.Athlete.Position.Validators.EquipmentExists do
  @moduledoc """
  Validates the 'equipment-exists' rule: If apparatusId or instrumentId is provided, the referenced equipment must exist

  Both sides of the rule are stated here, because the model states one rule, not
  two: the apparatus-reference field is checked by `validate/2`, the
  instrument-reference field by `validate_instrument/2`.

  The check crosses a constituent boundary, so it asks the equipment
  constituent's public API — never its internal API and never the `Repo`. A
  reference into another aggregate reports `:equipment_not_found`, not
  `:not_found`: `Sportipedia.Support.ErrorClassifier` collapses a `:not_found`
  inside a validation failure into a whole-command 404, and a request that names
  an unknown piece of equipment has one fixable attribute (422). See
  `docs/architecture/blueprints/backend/domain/examples/domain-object-exists.md`.

  Existence means *in the catalog*: equipment that has been archived answers
  `:equipment_not_found`, because archiving removes its read-model row. A
  position keeps its reference when its equipment is archived later — the catalog
  does not cascade.

  A legal reference is an **id**, never a slug: `read_apparatus/1` and
  `read_instrument/1` answer id *or* slug, so the check is guarded by
  `Sportipedia.Support.Validators.UuidValidator.valid_uuid?/1` — the same guard
  the [citizen's own existence check](domain-object-exists.md) puts in front of
  its lookup. Without it a slug would validate as "existing equipment", reach the
  `:binary_id` reference column, and poison the projection.
  """
  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Instrument
  alias Sportipedia.Support.Validators.UuidValidator

  @doc """
  Validates that the given apparatusId value references an apparatus in the
  catalog.
  """
  @spec validate(term(), map()) :: :ok | {:error, :equipment_not_found}
  def validate(apparatus_id, _context) do
    if UuidValidator.valid_uuid?(apparatus_id) do
      answer(Apparatus.read_apparatus(apparatus_id))
    else
      {:error, :equipment_not_found}
    end
  end

  @doc """
  Validates that the given instrumentId value references an instrument in the
  catalog.
  """
  @spec validate_instrument(term(), map()) :: :ok | {:error, :equipment_not_found}
  def validate_instrument(instrument_id, _context) do
    if UuidValidator.valid_uuid?(instrument_id) do
      answer(Instrument.read_instrument(instrument_id))
    else
      {:error, :equipment_not_found}
    end
  end

  # One answer for both kinds: the rule is about the equipment, not about which
  # kind of equipment it is.
  defp answer({:ok, _equipment}), do: :ok
  defp answer({:error, _reason}), do: {:error, :equipment_not_found}
end
