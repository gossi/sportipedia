# Query

| Attribute | Value |
| --- | --- |
| Schema | [Core](../../../../schemas/core/v1.yaml) |
| File Path | `/services/api/lib/sportipedia/<_subdomain>/<_composite>/<domain_object>/queries/<_query>.ex` |
| Module Name | `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<Query>` |
| Test | See [Operation Test](./operation-test.md) |

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the query

## Implementation

- Query modules use `import Ecto.Query` pattern with a struct and `new/1` constructor

### Documentation

Derive all documentation from the [Domain Model](../../../../domain-model/README.md):

- **`@moduledoc`**: Describe the query's purpose.
- **`@doc`**: Describe the `new/1` function.

Example:

```elixir
@moduledoc """
Query to fetch sports by their attributes.
"""

@doc """
Creates a new query to fetch sports.
"""
```

### Implementation Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Queries.<Query> do
  @moduledoc """
  Query to fetch <domain_object>s by their attributes.
  """

  import Ecto.Query

  @doc """
  Creates a new query to fetch <domain_object>s.
  """
  @spec new(<param_type>) :: Ecto.Query.t()
  def new(<params>) do
    # construct and return query
  end
end
```

### Example: Unique Slug

See [Unique Slug Example](./examples/unique-slug.md)

## Test
