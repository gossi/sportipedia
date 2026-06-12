# Command

| Attribute | Value |
| --- | --- |
| Schema | [Core](../../../../schemas/core/v1.yaml) |
| File Path | `/services/api/lib/sportipedia/<_subdomain>/<_composite>/<domain_object>/operation/<_operation>/command.ex` |
| Module Name | `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>` |
| Test | See [Operation Test](./operation-test.md) |

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the command,
  rules and invariants

## Implementation

- Is a `commanded` command
- Struct creation with enforced fields
  - use TypedStruct
  - use ExConstructor
  - use field-level `enforce: true` on each required field, NOT struct-level `enforce: true`

### Validation

When needed use `vex` to validate commands.

Read [Vex documentation](https://hexdocs.pm/vex/)

- `use Vex.Struct` on the command
- use `validates :<_field>` with built-in checks, eg. `presence: true`

#### Custom Validations

Vex allows custom validations

- Use a [custom validator](./validator.md)
- apply it with `by: [function: &<Validator>.validate/2]` and combine it with needed options
  - use `allow_nil: true` when domain logic requires it to

### Documentation

Derive all documentation from the [Domain Model](../../../../domain-model/README.md):

- **`@moduledoc`**: Describe what the command does to the aggregate, using the command name from the domain model.
- **`@doc`**: Describe the `new/1` function (creates a new command instance).

Example:

```elixir
@moduledoc """
Suggests a new sport to the catalog.
"""

@doc """
Creates a new SuggestSport command.
"""
```

### Implementation Template

- use `alias` for the validator

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command> do
  @moduledoc """
  <Describe what the command does to the aggregate, derived from the domain model.>
  """

  use TypedStruct
  use ExConstructor

  @doc """
  Creates a new <Command> command.
  """
  typedstruct do
    field :<_field>, <field type>, enforce: true/false
  end

  # Validation
  use Vex.Struct

  validates :title, presence: true
  validates :slug, presence: true, by: [function: &Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Validators.<Validator>.validate/2]
end
```

### Register Command

- register at a commanded router
- router locations: `/services/api/lib/sportipedia/<_subdomain>/<_composite>/router.ex`
- dispatch contents:

```elixir
  identify <DomainObject>Aggregate, by: :id, prefix: "<-composite>/<domain-object>/"
  dispatch <Command>, to: <Command>Handler, aggregate: <DomainObject>Aggregate
```

## Tests

What to test:

- Struct creation with enforced fields
  - When testing enforced fields, use `struct!(Command, %{})` which raises
    `ArgumentError` if required fields are missing
  - Optional fields (no `enforce: true`) can be omitted in struct literals
    without raising — test this by creating events without optional fields
- Validation
