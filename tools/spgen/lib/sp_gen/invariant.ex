defmodule SpGen.Invariant.Pattern do
  @moduledoc """
  Contract of an invariant pattern — the executable counterpart of an example
  blueprint in `docs/architecture/blueprints/backend/domain/examples/`.

  A pattern recognizes the domain-model rules it implements from their
  `namedRule` (the stable `name` plus the prose `rule`) and yields the
  validator descriptor `SpGen.Context` carries in `ctx.validators`.

  * `resolve/3` — the descriptor for `rule`, or `nil` when this pattern does
    not implement it (the next pattern is asked)
  """

  @callback resolve(rule :: map(), field_names :: [String.t()], constituent :: String.t()) ::
              SpGen.Invariant.t() | nil
end

defmodule SpGen.Invariant do
  @moduledoc """
  The invariant patterns of the domain model.

  `docs/domain-model` states its rules as `namedRule`s: an aggregate's
  `invariants` and a command's `constraints`. A rule with an example blueprint
  (`examples/unique-slug.md`, `examples/domain-object-exists.md`) is not prose
  an operator has to interpret — it is a pattern that resolves into the code
  the example shows: the validator, and with it the citizen's lookup query,
  internal accessor, changeset constraint and `validates` line.

  Resolution reads only the rule's `name` and the fields the citizen carries,
  so the domain model stays the single input: `unique-slug` validates `slug`,
  `apparatus-exists` validates the `id` of the apparatus. Patterns are asked in
  `patterns/0` order. A rule no pattern claims either

  * names a field of the citizen → a scaffold validator (`kind: :rule`) the
    operator implements, or
  * names no field (an operational precondition such as
    `no-archive-when-in-use`) → nothing is generated, and the rule stays
    visible in `Context.unresolved/1` instead of being silently dropped.

  Adding an example blueprint means adding one module that implements
  `SpGen.Invariant.Pattern` and registering it here.
  """

  alias SpGen.Context

  @patterns [
    SpGen.Invariant.UniqueField,
    SpGen.Invariant.DomainObjectExists,
    SpGen.Invariant.FieldRule
  ]

  @typedoc """
  The validator descriptor a pattern resolves a rule to.

  * `kind` — `:unique` | `:exists` | `:rule`, the shape the validator,
    internal API and lookup-query blueprints render
  * `field` — the citizen field the rule guards
  * `module` / `snake` — the validator's module name and file name
  """
  @type t :: %{
          name: String.t(),
          rule: String.t() | nil,
          field: String.t(),
          kind: :unique | :exists | :rule,
          module: String.t(),
          snake: String.t()
        }

  @doc "The registered patterns, in resolution order."
  def patterns, do: @patterns

  @doc """
  Resolves one `namedRule` against the citizen's `field_names`; `nil` when no
  pattern implements the rule.
  """
  @spec resolve(map(), [String.t()], String.t()) :: t() | nil
  def resolve(%{"name" => _name} = rule, field_names, constituent) when is_list(field_names) do
    Enum.find_value(@patterns, fn pattern -> pattern.resolve(rule, field_names, constituent) end)
  end

  @doc """
  Splits `rules` into `{validators, unresolved}` in input order: the rules a
  pattern implements and the rules none of them claims.
  """
  @spec resolve_all([map()], [String.t()], String.t()) :: {[t()], [map()]}
  def resolve_all(rules, field_names, constituent) do
    rules
    |> Enum.map(fn rule -> resolve(rule, field_names, constituent) end)
    |> Enum.zip(rules)
    |> Enum.reduce({[], []}, fn
      {nil, rule}, {validators, unresolved} -> {validators, [rule | unresolved]}
      {validator, _rule}, {validators, unresolved} -> {[validator | validators], unresolved}
    end)
    |> then(fn {validators, unresolved} ->
      {Enum.reverse(validators), Enum.reverse(unresolved)}
    end)
  end

  @doc false
  @spec descriptor(map(), atom(), String.t()) :: t()
  def descriptor(%{"name" => name} = rule, kind, field) do
    %{
      name: name,
      field: field,
      kind: kind,
      rule: rule["rule"],
      module: Context.pascal(name),
      snake: String.replace(name, "-", "_")
    }
  end
end
