# Operation Test

Blueprint for a test file for one operation in the [Sportipedia Domain](../../../../domain-model/README.md).

| Attribute | Value |
| --- | --- |
| Test File | `/services/api/test/sportipedia/<_subdomain>/<_composite>/<domain-object>/operation/<_operation>_test.exs` |
| Test Module Name | `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test` |

## Test

The test may (if applicable) cover the following:

- [Policy](./policy.md)
- [Command](./command.md)
- [Command Handler](./command-handler.md)
- [Event](./event.md)
- Event Handler
- [Aggregate](./aggregate.md)
- [Projector](./projector.md)
- [Public API](./public-api.md)

Each is represented as a `describe` block in the test file and explained below.

### Test Template

Scaffolding template.

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test do
  use Sportipedia.<Subdomain>TestCase

  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Policy
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>Handler
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<Aggregate>
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<ReadModel>
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<Projector>
  alias Sportipedia.<Subdomain>.Repo
end
```
