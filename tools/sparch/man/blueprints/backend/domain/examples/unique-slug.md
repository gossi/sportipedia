---
invariant: unique-field
pattern: SpGen.Invariant.UniqueField
claims: "unique-<field>, where <field> is a field of the citizen"
---

# Unique Slug: Validator and Queries

A `unique-<field>` invariant: the value of `<field>` may belong to no other
domain object. This is the canonical instance of the pattern; `<field>` is the
parameter, `slug` the common case.

## Nothing here is hand-written

Generating the command that carries the rule writes all of it, in one run:

1. `Queries.<DomainObject>BySlug` — the lookup (executable:
   `SpGen.Blueprint.LookupQuery`),
2. `<DomainObject>Internal.<domain_object>_by_slug/1` — the accessor, lowering
   the value before the query (`SpGen.Blueprint.InternalAPI`),
3. `Validators.UniqueSlug` — the validator over that accessor
   (`SpGen.Blueprint.Validator`),
4. the read model with `unique_constraint(:slug)` in its changesets
   (`SpGen.Blueprint.ReadModel`),
5. `validates :slug, …, by: [function: &UniqueSlug.validate/2]` on the command.

The code below is the reference for **review**, not a template to copy. If the
generated file differs, the generator is wrong — fix `SpGen.Blueprint`, not the
file.

## Contract

- Duplicate value → `{:error, :<field>_exists}`.
- The record that already owns the value passes (the edit case): the validator
  compares the found row's `id` against `context.id`.
- An absent value is not the validator's business — the command's
  `allow_nil: true` decides that.
- The canonical form of a slug is **lowercase, stored by the write side**: the
  command handler emits the fact with the value lowered, so the read model
  holds one spelling per slug and the accessor's `String.downcase` only has to
  meet the stored value. The lowercasing is the write side's, not a convention
  the reader may skip — and it is what lets the database back uniqueness with a
  **plain** unique index: no case-expression, no functional index, because the
  indexed column already holds one spelling
  ([migration](../migration.md)).
- The database needs the matching unique index; see
  [migration](../migration.md).

## The pieces it realizes

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<DomainObject>BySlug do
  @moduledoc """
  Query to fetch a <domain_object> by its slug.
  """

  import Ecto.Query
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel

  def new(slug) do
    from(r in <DomainObject>ReadModel,
      where: r.slug == ^slug
    )
  end
end
```

```elixir
def <domain_object>_by_slug(slug) do
  slug
  |> String.downcase()
  |> <DomainObject>BySlug.new()
  |> Repo.one()
end
```

```elixir
def validate(value, context) do
  with <domain_object> <- <DomainObject>Internal.<domain_object>_by_slug(value),
       false <- is_nil(<domain_object>),
       false <- slug_belongs_to_<domain_object>?(<domain_object>, context) do
    {:error, :slug_exists}
  else
    _ -> :ok
  end
end

defp slug_belongs_to_<domain_object>?(<domain_object>, context) do
  Map.get(context, :id) == <domain_object>.id
end
```

## Tests

Asserted in the [command's tests](../command.md#tests): duplicate rejected,
unchanged value on edit accepted, a value owned by another record rejected.

## Learnings

### Finding: two error conventions for one rule

#### DO NOT

Return `{:error, "slug already exists"}` in one citizen and `{:error,
:slug_exists}` in another.

#### DO INSTEAD

The atom the pattern defines, `{:error, :<field>_exists}`, and the same atom in
the test assertion. Documentation and code that disagree about this are a bug in
one of them.
