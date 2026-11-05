defmodule SpGen.Invariant.FieldRule do
  @moduledoc """
  The fallback for a rule no example blueprint covers yet.

  When the rule names a field of the citizen — a cross-field invariant such as
  `at-most-one-equipment`, a cross-aggregate precondition such as
  `equipment-exists` — it becomes a scaffold validator (`kind: :rule`) that
  raises a stable `TODO:` marker: the shape is the operator's, the invariant is
  the model's.

  A rule naming no field is not a validator at all (an operational precondition
  over another bounded context) and resolves to `nil`, which keeps it in
  `SpGen.Context.unresolved`.
  """

  @behaviour SpGen.Invariant.Pattern

  alias SpGen.Invariant

  @impl true
  def resolve(%{"name" => name} = rule, field_names, _constituent) do
    text = "#{name} #{rule["rule"]}"

    case Enum.find(field_names, fn field -> text =~ ~r/\b#{Regex.escape(field)}\b/i end) do
      nil -> nil
      field -> Invariant.descriptor(rule, :rule, field)
    end
  end

  def resolve(_rule, _field_names, _constituent), do: nil
end
