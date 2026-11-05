defmodule SpGen.Invariant.UniqueField do
  @moduledoc """
  The `unique-<field>` pattern:
  `docs/architecture/blueprints/backend/domain/examples/unique-slug.md`.

  The value of `<field>` may belong to no other domain object. It is validated
  through the internal API accessor `<domain_object>_by_<field>`, tolerating
  the object that already owns the value (the edit case), which makes the
  pattern claim the lookup query and the accessor next to the validator.
  """

  @behaviour SpGen.Invariant.Pattern

  alias SpGen.Invariant

  @impl true
  def resolve(%{"name" => "unique-" <> field} = rule, field_names, _constituent) do
    if field in field_names, do: Invariant.descriptor(rule, :unique, field)
  end

  def resolve(_rule, _field_names, _constituent), do: nil
end
