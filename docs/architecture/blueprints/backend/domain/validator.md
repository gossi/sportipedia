# Validator

| Attribute | Value |
| --- | --- |
| Schema | [Core](../../schemas/core/v1.yaml) |
| File Path | `/services/api/lib/sportipedia/<_subdomain>/<_composite>/<domain_object>/validators/<_validator>.ex` |
| Module Name | `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Validators.<Validator>` |
| Test | See [Operation Test](./operation-test.md) |

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) has an invariant/rule
  implemented as validator

## Implementation

- `use Vex.Validator` on the validator
- **Critical**: Do NOT configure them as "global" validators
- implementation logic:
  - according to test the given invariance
  - May make use of a given query (if applicable)
- if `nil` values are allowed:
  - DO NOT: `def validate(nil, _contex), do: :ok`
  - DO: use [`allow_nil: true`](./command.md#custom-validations)

### Implementation Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Validators.<Validator> do
  use Vex.Validator

  def validate(value, _context) do
    # run logic
  end
end
```

### Example: Unique Slug

See [Unique Slug Example](./examples/unique-slug.md)

## Test

Done as part of testing a [command](./command.md)
