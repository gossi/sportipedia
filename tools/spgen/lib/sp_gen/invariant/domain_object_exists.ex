defmodule SpGen.Invariant.DomainObjectExists do
  @moduledoc """
  The `<domain_object>-exists` pattern:
  `docs/architecture/blueprints/backend/domain/examples/domain-object-exists.md`.

  For many operations the domain object the command addresses has to exist;
  existence is checked by id through the internal API's
  `<domain_object>_by_id/1`. A rule naming another domain object (e.g.
  `equipment-exists` on a position) is not this pattern: it is a precondition
  on a reference, not on the citizen itself.
  """

  @behaviour SpGen.Invariant.Pattern

  alias SpGen.Invariant

  @impl true
  def resolve(%{"name" => name} = rule, field_names, constituent) do
    if name == "#{constituent}-exists" and "id" in field_names do
      Invariant.descriptor(rule, :exists, "id")
    end
  end

  def resolve(_rule, _field_names, _constituent), do: nil
end
