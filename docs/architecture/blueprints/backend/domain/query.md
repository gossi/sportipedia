# Query

| Attribute | Value |
| --- | --- |
| Schema | [Core](../../schemas/core/v1.yaml) |
| File Path | `/services/api/lib/sportipedia/<_subdomain>/<_composite>/<domain_object>/queries/<_query>.ex` |
| Module Name | `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<Query>` |
| Test | See [Operation Test](./operation-test.md) |

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the query

## Implementation

- Query modules use `import Ecto.Query` pattern with a struct and `new/1` constructor

### Implementation Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<Query> do
  import Ecto.Query

  def new(params) do
    # construct and return query
  end
end
```

### Example: Unique Slug

See [Unique Slug Example](./examples/unique-slug.md)

## Test
