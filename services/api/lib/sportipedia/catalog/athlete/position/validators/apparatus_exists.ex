defmodule Sportipedia.Catalog.Athlete.Position.Validators.ApparatusExists do
  @moduledoc """
  Validates the 'equipment-exists' rule: If apparatusId or instrumentId is
  provided, the referenced equipment must exist. This is the apparatus side of
  that rule.

  The check crosses a constituent boundary, so it asks the equipment
  constituent's public API — never its internal API and never the `Repo`. A
  reference into another aggregate reports `:equipment_not_found`, not
  `:not_found`: `Sportipedia.Support.ErrorClassifier` collapses a `:not_found`
  inside a validation failure into a whole-command 404, and a request that names
  an unknown apparatus is a fixable attribute (422). See
  `docs/architecture/blueprints/backend/domain/examples/domain-object-exists.md`.
  """
  use Vex.Validator

  alias Sportipedia.Catalog.Equipment.Apparatus

  @doc """
  Validates that the given apparatus id references an existing apparatus.
  """
  @spec validate(String.t(), map()) :: :ok | {:error, :equipment_not_found}
  def validate(apparatus_id, _context) do
    case Apparatus.read_apparatus(apparatus_id) do
      {:ok, _apparatus} -> :ok
      {:error, :not_found} -> {:error, :equipment_not_found}
    end
  end
end
