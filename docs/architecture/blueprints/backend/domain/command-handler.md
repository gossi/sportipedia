# Command Handler

| Attribute | Value |
| --- | --- |
| Schema | [Core](../../../../schemas/core/v1.yaml) (see `command`) |
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

### Documentation

Derive all documentation from the [Domain Model](../../../../domain-model/README.md):

- **`@moduledoc`**: Describe the handler's purpose in handling the command.
- **`@doc`**: Describe the `handle/2` function.

Example:

```elixir
@moduledoc """
Handles the SuggestSport command.
"""

@doc """
Handles the SuggestSport command and returns a SportSuggested event.
"""
```

### Implementation Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>Handler do
  @moduledoc """
  Handles the <Command> command.
  """

  @behaviour Commanded.Commands.Handler

  @doc """
  Handles the <Command> command and returns <Event> event(s).
  """
  @spec handle(<DomainObject>Aggregate.t(), <Command>.t()) :: <Event>.t() | [<Event>.t()]
  def handle(%<DomainObject>Aggregate{} = aggregate, %<Command>{} = cmd) do
    # implement logic here
    # return events
  end
end
```

## Test

Tests the command handlers, input into output. Ideally pure, integration tests when needed.
