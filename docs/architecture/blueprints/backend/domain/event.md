# Event

| Attribute | Value |
| --- | --- |
| Schema | [Core](../../../../schemas/core/v1.yaml) |
| File Path | `/services/api/lib/sportipedia/<_subdomain>/<_composite>/<domain_object>/event.ex` |
| Module Name | `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>` |
| Test | See [Operation Test](./operation-test.md) |

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the event

## Implementation

Facts about the system

- Struct creation with enforced fields
  - use `TypedStruct`
  - use `ExConstructor`
- Add `@derive Jason.Encoder` before `typedstruct` to enable JSON serialization
  (required for event serialization in tests and event store)
- Use `typedstruct` (no `enforce: true` at struct level) — enforce only on
  required fields individually. Optional fields must NOT have `enforce: true`.

### Documentation

Derive all documentation from the [Domain Model](../../../../domain-model/README.md):

- **`@moduledoc`**: Describe what happened in the domain, using the event name.
- **`@doc`**: Describe the `new/1` function (creates a new event instance).

Example:

```elixir
@moduledoc """
A sport was suggested to the catalog.
"""

@doc """
Creates a new SportSuggested event.
"""
```

### Implementation Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event> do
  @moduledoc """
  <Describe what happened in the domain, derived from the event name.>
  """

  use TypedStruct
  use ExConstructor

  @derive Jason.Encoder
  @doc """
  Creates a new <Event> event.
  """
  typedstruct do
    field :<_field>, <field type>, enforce: true/false
  end
end
```

## Test

Tests events.

- Struct creation with enforced fields
  - When testing enforced fields, use `struct!(Event, %{})` which raises
    `ArgumentError` if required fields are missing
  - Optional fields (no `enforce: true`) can be omitted in struct literals
    without raising — test this by creating events without optional fields
- Serialization, via `Jason.encode!(event)`
