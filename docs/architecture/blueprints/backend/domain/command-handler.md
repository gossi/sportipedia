# Command Handler

| Attribute | Value |
| --- | --- |
| Schema | [Core](../../schemas/core/v1.yaml) (see `command`) |
| File Path | `/services/api/lib/sportipedia/<_subdomain>/<_composite>/<domain_object>/<_operation>/handler.ex` |
| Module Name | `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>Handler` |
| Test | See [Operation Test](./operation-test.md) |

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the command

## Implementation

Implement the actual command behavior.

- Is a `commanded` command-handler
- Takes the command as input
- Outputs events

- Implementation depth:
  - Shallow by mapping the command to events
  - Deep to handle complex business logic

### Implementation Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>Handler do
  @behaviour Commanded.Commands.Handler

  def handle(aggregate, %<Command>{} = cmd) do
    # implement logic here
    # return events
  end
end
```

## Test

Tests the command handlers, input into output. Ideally pure, integration tests when needed.
