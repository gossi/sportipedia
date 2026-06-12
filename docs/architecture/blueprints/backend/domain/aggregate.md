# Aggregate

| Attribute | Value |
| --- | --- |
| Schema | [Core](../../schemas/core/v1.yaml) |
| File Path | `/services/api/lib/sportipedia/<_subdomain>/<_composite>/<domain_object>/aggregate.ex` |
| Module Name | `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate` |
| Test | See [Operation Test](./operation-test.md) |

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the aggregate

## Implementation

- Use `TypedStruct` (not `defstruct`) for the aggregate struct

### Evolve State

- One `apply/2` function clause per event type
  - Pattern match both aggregate and event in the function head
- Return a new aggregate struct with updated fields
- For events resulting in deleting the aggregate, return `nil`

### Documentation

Derive all documentation from the [Domain Model](../../../../domain-model/README.md):

- **`@moduledoc`**: Describe the aggregate's purpose in the bounded context.
- **`@doc`**: Describe the `apply/2` function.

Example:

```elixir
@moduledoc """
Aggregate representing a sport in the catalog.
"""

@doc """
Applies an event to the sport aggregate state.
"""
```

### Implementation Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate do
  @moduledoc """
  Aggregate representing a <domain_object> in the <bounded_context>.
  """

  use TypedStruct

  typedstruct do
    field :<field>, type
  end

  @doc """
  Applies an event to the <domain_object> aggregate state.
  """
  @spec apply(%__MODULE__{}, <Event>.t()) :: %__MODULE__{} | nil
  def apply(%__MODULE__{} = aggregate, %<Event>{} = event) do
    # apply event to aggregate
  end
end
```

## Test

Tests `Aggregate.apply/2` for the specific event.

```elixir
test "applies <-event> to aggregate state" do
  event = %<Event>{...}
  result = Aggregate.apply(%Aggregate{}, event)
  assert result.field == value
end
```
