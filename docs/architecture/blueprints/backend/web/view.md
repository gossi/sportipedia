# View

| Attribute        | Value                                                                                          |
| ---------------- | ---------------------------------------------------------------------------------------------- |
| File Path        | `/services/api/lib/sportipedia_web/<_subdomain>/<_composite>/<domain_object>_view.ex`          |
| Module Name      | `SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>View`                                    |
| Test File Path   | `test/sportipedia_web/<_subdomain>/<_composite>/<domain_object>/<domain_object>_view_test.exs` |
| Test Module Name | `SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>ViewTest`                                |

Blueprint for implementing a JSONAPI view for the [web layer](../../../backend.md) representing a read model in the [Sportipedia domain](../../../../domain-model/README.md).

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the read model.

## Implementation

Representing a domain object in JSON API

- `use JSONAPI.View`
- based on the read model

### Implementation Template

```elixir
defmodule SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>View do
  use JSONAPI.View, type: "<domain-object>s"

  def path, do: "<-subdomain>/<-composite>/<domain-object>s"

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
defmodule SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>ViewTest do
  use SportipediaWeb.ConnCase

  alias SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>View
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
