# Read Model

| Attribute | Value |
| --- | --- |
| Schema | [Core](../../schemas/core/v1.yaml) |
| File Path | `/services/api/lib/sportipedia/<_subdomain>/<_composite>/<domain_object>/read_model.ex` |
| Module Name | `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel` |
| Test | See [Operation Test](./operation-test.md) |

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the domain model

## Implementation

Read Model for querying.

- Struct creation with enforced fields
  - Use `TypedEctoSchema`
  - Use `Ecto.Changeset`
- Contains necessary changeset function for this operation

### Changeset Functions

A read model usually has a couple of changeset functions.

- Changeset functions need to contain all information to ensure referential integrity
- Name them after their database operation
  - `insert_changeset`
  - `update_changeset`
- Use custom changesets, if they are needed for certain operations (only if the two above wouldn't work)

### Implementation Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel do
  use TypedEctoSchema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @schema_prefix "<_subdomain>"

  typed_schema "<domain_object>" do
    field :<_field>, <field type>, <field opts>

    timestamps()
  end

  # changesets
end
```

### Migration

See [Migration](./migration.md)

## Test
