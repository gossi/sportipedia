# Policy

| Attribute | Value |
| --- | --- |
| Schema | [Core](../../schemas/core/v1.yaml) (see `command` + `actor`) |
| File Path | `/services/api/lib/sportipedia/<_subdomain>/<_composite>/<domain_object>/policy.ex` |
| Module Name | `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Policy` |
| Test | See [Operation Test](./operation-test.md) |

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the command
  with actors

## Implementation

Derive authorization from the domain model and present rules and invariants.

- Policy uses the bodyguard framework
- One function for "can actor do x for y"
- Only functions needed for the given operation
- Basis are the `actor` in the domain model. MUST use guards from `Sportipedia.Auth`:
  - `is_guest?(user)`
  - `is_user?(user)`
  - `is_admin?(user)`
  - Pick the relevant for the implementation at hand (not all three are always needed).
    When guests are allowed, all others are too.
    When a user is allowed, so are admins.
- By using the provided guards the checks are centralized and guaranteed to be equal everywhere

### Documentation

Derive all documentation from the [Domain Model](../../../../domain-model/README.md):

- **`@moduledoc`**: Describe the policy's purpose in authorizing operations.
- **`@doc`**: Describe the `authorize/3` function.

Example:

```elixir
@moduledoc """
Authorizes sport operations based on user roles.
"""

@doc """
Authorizes whether the given user can perform the operation.
"""
```

### Implementation Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Policy do
  @moduledoc """
  Authorizes <domain_object> operations based on user roles.
  """

  @behaviour Bodyguard.Policy

  import Sportipedia.Auth.Roles

  @doc """
  Authorizes whether the given user can perform the <_operation> operation.
  """
  @spec authorize(:<_operation>, Sportipedia.Auth.User.t() | nil, map()) :: :ok | :error
  def authorize(:<_operation>, user, _params) when is_guest?(user), do: :error
  def authorize(:<_operation>, user, _params) when is_user?(user), do: :ok
end
```

## Test

Tests `Policy.authorize/3` — pure function
