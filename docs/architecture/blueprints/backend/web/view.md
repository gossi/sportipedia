# View

| Attribute        | Value                                                                                          |
| ---------------- | ---------------------------------------------------------------------------------------------- |
| File Path        | `/services/api/lib/sportipedia_web/<_subdomain>/<_composite>/<domain_object>/<domain_object>_view.ex`          |
| Module Name      | `SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>View`                                    |
| Test File Path   | `/services/api/test/sportipedia_web/<_subdomain>/<_composite>/<domain_object>/<domain_object>_view_test.exs` |
| Test Module Name | `SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ViewTest`                                |

Blueprint for implementing a JSONAPI view for the [web layer](../../../backend.md) representing a read model in the [Sportipedia domain](../../../../domain-model/README.md).

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the read model.

## Implementation

Representing a domain object in JSON API

- `use JSONAPI.View`
- based on the read model

### Documentation

Derive all documentation from the [Domain Model](../../../../domain-model/README.md):

- **`@moduledoc`**: Describe the view's purpose for rendering the read model.
- **`@doc`**: Describe each function's purpose.

Example:

```elixir
@moduledoc """
Renders sport resources in JSON:API format.
"""

@doc """
Returns the path for sport resources.
"""

@doc """
Returns the fields for rendering a sport.
"""
```

### Implementation Template

```elixir
defmodule SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>View do
  @moduledoc """
  Renders <domain_object> resources in JSON:API format.
  """

  use JSONAPI.View, type: "<domain-object>s"

  @doc """
  Returns the path for <domain_object> resources.
  """
  def path, do: "<-subdomain>/<-composite>/<domain-object>s"

  @doc """
  Returns the fields for rendering a <domain_object>.
  """
  def fields, do: [
    # fields
  ]
end
```

## Test

The JSONAPI View's `render` function requires a `Plug.Conn` struct with fetched params:

Also test `type/0`, `fields/0`, `path/0` as unit tests.

### Test Template

```elixir
defmodule SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ViewTest do
  use SportipediaWeb.ConnCase

  alias SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>View
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel

  import SportipediaWeb.RequestHelpers

  test "render show.json produces JSON:API single document" do
    <domain_object> = %<DomainObject>{...}
    conn = build_conn() |> fetch_query_params()
    result = <DomainObject>View.render("show.json", %{data: <domain_object>, conn: conn})

    assert %{data: %{id: _, type: "<jsonapi-type>", attributes: %{...}}} = result
  end
end
```
