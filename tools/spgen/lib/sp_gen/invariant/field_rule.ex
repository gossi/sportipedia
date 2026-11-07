defmodule SpGen.Invariant.FieldRule do
  @moduledoc """
  The fallback for a rule no example blueprint covers yet.

  When the rule names fields of the citizen — a cross-field invariant such as
  `at-most-one-equipment`, a cross-aggregate precondition such as
  `equipment-exists` — each named field yields a scaffold validator
  descriptor (`kind: :rule`) that raises a stable `TODO:` marker: the shape is
  the operator's, the invariant is the model's.

  *Every* named field, not just the first: a rule is a fact about the data
  shape, and it holds of every command field it names. Registering only the
  first one leaves the other half of the rule unreachable for the generator —
  a fresh build would drop the registration in silence, and `--check` only
  sees missing units it knows about. One rule, one validator module; the
  module's per-field clauses (`validate_instrument/2` and friends) are the
  operator's, the registration on every named field is the generator's.

  A rule naming no field is not a validator at all (an operational precondition
  over another bounded context) and resolves to `nil`, which keeps it in
  `SpGen.Context.unresolved`.
  """

  @behaviour SpGen.Invariant.Pattern

  alias SpGen.Invariant

  @impl true
  def resolve(%{"name" => name} = rule, field_names, _constituent) do
    text = "#{name} #{rule["rule"]}"

    named = Enum.filter(field_names, fn field -> text =~ ~r/\b#{Regex.escape(field)}\b/i end)

    if named == [],
      do: nil,
      else: Enum.map(named, fn field -> Invariant.descriptor(rule, :rule, field) end)
  end

  def resolve(_rule, _field_names, _constituent), do: nil
end
