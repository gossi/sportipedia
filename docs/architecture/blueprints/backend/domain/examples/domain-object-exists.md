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
  operator's, the rule is the model's.
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
knows.
