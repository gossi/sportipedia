---
invariant: domain-object-exists
pattern: SpGen.Invariant.DomainObjectExists
claims: "<domain-object>-exists, where <domain-object> is the citizen itself and id is one of its fields"
---

# Domain Object Exists: Validator

A command that addresses an existing domain object must fail when that object is
not there. Existence is checked by `id` through the internal API — behind a UUID
guard, because the check is a `Repo.get/2` on the primary key and `Repo.get/2`
raises on values it cannot put there.

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

- Unknown id → `{:error, :not_found}` → `404`.
- Existing id → `:ok`.
- Malformed id (`"not-a-uuid"`, `123`) → `{:error, :not_found}` too → `404`.
  A value that cannot denote the resource denotes no resource — that is the
  pattern's own verdict for an unknown id. It must not reach `Repo.get/2`,
  which raises `Ecto.Query.CastError` on it: a raise in a validator reaches
  the client as a `500`. The check is
  `Sportipedia.Support.Validators.UuidValidator.valid_uuid?/1`, and the guard
  itself cannot raise (`Ecto.UUID.dump/1` is total).
- Absent or blank id (`nil`, `""`) → **not this validator's to answer**. The
  command's `validates` line skips it (`allow_blank: true`) and `presence`
  rejects → `422`. Handing a blank id to the lookup raises (`Repo.get/2` on
  `nil` / `""`), and answering `:not_found` for it would be collapsed by
  `Sportipedia.Support.ErrorClassifier` into a whole-command `404` for a
  resource nobody named. `allow_blank` covers absent *and* empty
  (`Vex.Blank.blank?/1` — nil, `""`, `[]`, `%{}`, `false`); `allow_nil` alone
  would still run the lookup on `""`.
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
  alias Sportipedia.Support.Validators.UuidValidator

  @doc """
  Validates the given id value.
  """
  # `term()`, not `String.t()`: the value reaches here straight off the request,
  # and a request can name an id with anything at all.
  @spec validate(term(), map()) :: :ok | {:error, :not_found}
  def validate(id, _context) do
    # A value that cannot denote a <domain_object> denotes no <domain_object>:
    # the pattern's verdict for an unknown id, given without leaving the
    # process — `Repo.get/2` would raise on it instead.
    if UuidValidator.valid_uuid?(id) do
      case <DomainObject>Internal.<domain_object>_by_id(id) do
        nil -> {:error, :not_found}
        _<domain_object> -> :ok
      end
    else
      {:error, :not_found}
    end
  end
end
```

Used from the [command](../command.md):

```elixir
  # `allow_blank` keeps the existence check off an id the caller never sent: an
  # absent address is `presence`'s to reject, and a `:not_found` for it would
  # turn the 422 the client can act on into a 404 for a resource nobody named.
  validates :id,
    presence: true,
    by: [function: &<DomainObject>Exists.validate/2, allow_blank: true]
```

`allow_blank`, never a `def validate(nil, _), do: :ok` clause — see
[validator](../validator.md#contracts): the skip option belongs to the command
line, where the rule that owns optionality (`presence`) is visible next to it.
And `allow_blank`, not `allow_nil`: `Vex.Skipping.skip?/2` checks
`allow_blank` first and delegates to `Vex.Blank.blank?/1`; with `allow_nil`
alone the lookup would still run on `""`.

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
- A legal reference is an **id, never a slug**: the referenced read is polymorphic
  (id *or* slug), so "some equipment exists under this text" is not "this value
  is a legal reference". Guard with
  `Sportipedia.Support.Validators.UuidValidator.valid_uuid?/1` and answer
  `{:error, :<referenced-thing>_not_found}` for a value that cannot denote an id
  — the reference column is `:binary_id`, and an unguarded slug passes validation
  and poisons the projection.

Why the atom is not `:not_found`, even though this pattern's own contract uses
it, is in [the finding below](#finding-not_found-as-a-reference-rule-atom).

## Tests

Asserted in the [command's tests](../command.md#tests): an id that is not in the
database is rejected with `:not_found`, a cataloged one validates. Assert the
rule that speaks, never a crash:

- `nil` or `""` as id → `presence` is the only rule that speaks for it
  (`[:presence]`). The shape to refuse is `assert_raise ArgumentError, fn ->
  Vex.validate(cmd) end` — that test passes *only while the 500 bug exists*,
  green against a command answering through its own exception.
- malformed id (`"not-a-uuid"`) → the existence rule answers with the unknown-id
  verdict (`[:by]`, classified `404`), and the lookup is not what delivers it —
  the guard does, without touching the database.

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
