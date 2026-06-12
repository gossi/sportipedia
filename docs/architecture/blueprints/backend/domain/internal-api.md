# Internal API

| Attribute | Value |
| --- | --- |
| File Path | `/services/api/lib/sportipedia/<_subdomain>/<_composite>/<domain_object>/internal_api` |
| Module Name | `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal` |
| Test | See [Operation Test](./operation-test.md) |

## Implementation

Internal API is used within a constituent (including tests), but never from another constituent or composite.

What it contains:

- Functions with descriptive names do hide implementation details to make the API memorable
- Functions may call the implementation from elsewhere, eg. use an existing query
- Function to get the read models via id: `<domain_object>_by_id(id)` and `<domain_object>_by_id!(id)` - the latter used in tests.

What it does not contain:

- Technical implemetation that has a better place to live elsewhere (eg. in a query or a validator)

### Implementation Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal do
  @spec <domain_object>_by_id(String.t()) :: <DomainObject>ReadModel.t() | nil
  def <domain_object>_by_id(id) do
    # ecto query to read one record by id
  end

  @spec <domain_object>_by_id!(String.t()) :: <DomainObject>ReadModel.t()
  def <domain_object>_by_id!(id) do
    # ecto query to read one record by id
  end
end
```

### Example: Unique Slug

See [Unique Slug Example](./examples/unique-slug.md)

## Test
