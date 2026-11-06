---
invariant: domain-object-exists
pattern: SpGen.Invariant.DomainObjectExists
claims: "<domain-object>-exists, where <domain-object> is the citizen itself and id is one of its fields"
---

# Domain Object Exists: Validator

A command that addresses an existing domain object must fail when that object is
not there. Existence is checked by `id` through the internal API.

## What this pattern claims — and what it does not

- `<domain_object>-exists` **on its own citizen**, with `id` among the fields →
  this pattern: the validator plus the `validates :id, by: …` line, and the
  internal `x_by_id/1` it calls.
- A rule naming a *different* domain object — `apparatus-exists`,
  `equipment-exists` on a position — is a precondition on a reference, not on the
  citizen. It falls through to `SpGen.Invariant.FieldRule` and arrives as a
  scaffold validator that raises a `TODO:` marker: the shape of that check is the
  operator's, the rule is the model's. Its contract is
  [Cross-aggregate reference rules](#cross-aggregate-reference-rules); the
  contract below is only for the citizen's own `id`.
- A rule naming no field at all (an operational precondition such as
  `no-archive-when-in-use`) is not a validator: it stays in
  `SpGen.Context.unresolved` and produces nothing, so implement it yourself
  (validator and `validates … by:` line).

## Contract

- Unknown id → `{:error, :not_found}`.
- Existing id → `:ok`.
- The internal API returns `nil` when the row is missing; the validator turns
  that into the error. No second lookup, no `Repo` call from the validator.

## The pieces it realizes

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Validators.<DomainObject>Exists do
  @moduledoc """
  Validates that a <domain_object> exists.
  """

  use Vex.Validator
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal

  @spec validate(String.t(), map()) :: :ok | {:error, term()}
  def validate(id, _context) do
    case <DomainObject>Internal.<domain_object>_by_id(id) do
      nil -> {:error, :not_found}
      _ -> :ok
    end
  end
end
```

Used from the [command](../command.md):

```elixir
validates :id, presence: true, by: [function: &<DomainObject>Exists.validate/2]
```

## Cross-aggregate reference rules

A rule that names a field of the citizen but checks an object of **another**
aggregate — `equipment-exists` on `catalog-position`, where `apparatusId` and
`instrumentId` point into equipment — is not this pattern. `SpGen.Invariant`
hands it to `SpGen.Invariant.FieldRule` as a scaffold: the validator file exists,
its body and its error atom do not. The contract below is what filled them, and
what the next reference rule copies.

- Missing referenced object → `{:error, :<referenced-thing>_not_found}`. For
  `equipment-exists` that is `{:error, :equipment_not_found}`, one atom for both
  the apparatus and the instrument validator: the rule is about the equipment, not
  about which kind of equipment.
- Existing referenced object → `:ok`.
- Optionality stays on the command's `validates` line (`allow_nil: true`), never a
  `validate(nil, _)` clause — see [validator](../validator.md#contracts).
- The lookup goes through the referenced constituent's **public API**
  (`Apparatus.read_apparatus/1`), not its internal API and not `Repo`: the check
  crosses a constituent boundary, so it asks the port, not the store.

Why the atom is not `:not_found`, even though this pattern's own contract uses
it, is in [the finding below](#finding-not_found-as-a-reference-rule-atom).

## Tests

Asserted in the [command's tests](../command.md#tests): an id that is not in the
database is rejected with `:not_found`, a cataloged one validates.

## Learnings

### Finding: "does not exist" as a message

#### DO NOT

`{:error, "<domain_object> does not exist"}` — a string that no caller can match
on, and a second convention beside `:not_found`.

#### DO INSTEAD

`{:error, :not_found}`, the atom the pattern emits and the read side already
knows — on the citizen's own existence check. A reference into another aggregate
needs its own atom, see
[the next finding](#finding-not_found-as-a-reference-rule-atom).

### Finding: `:not_found` as a reference-rule atom

#### DO NOT

Reuse `{:error, :not_found}` in a cross-aggregate reference validator because the
citizen's own existence check uses it. `Sportipedia.Support.ErrorClassifier`
scans a command's validation failures for `:not_found` and, on a hit, throws the
field detail away and returns `{:error, :not_found}` for the whole command. So
cataloging a position against an apparatus id that does not exist answers `404` —
"the position you asked for is not there" — for a request that created nothing and
whose real problem is one attribute the client can fix.

#### DO INSTEAD

Give the reference rule an atom of its own: `{:error, :equipment_not_found}`. It
is not the one `ErrorClassifier` collapses, so it survives as
`{:error, {:validation_failure, %{apparatusId: [:equipment_not_found]}}}` and
renders `422` with the field and the reason. Assert it in the command test — that
assertion is where the atom is pinned down.
