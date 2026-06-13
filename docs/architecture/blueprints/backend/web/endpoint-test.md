# Endpoint Test

Blueprint for testing an endpoint (CQRS/ES operation) in the Sportipedia domain.

| Attribute   | Value                                                                                                     |
| ----------- | --------------------------------------------------------------------------------------------------------- |
| File Path   | `test/sportipedia_web/<_subdomain>/<_composite>/<domain_object>/operation/<_operation>_endpoint_test.exs` |
| Module Name | `SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<Operation>EndpointTest`                           |

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the operation but also its behavior and/or test instructions.

## Test

### Test Module Template

```elixir
defmodule SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<Operation>EndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<ReadModel>
  alias SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>View
end
```

`SportipediaWeb.ConnCase` manages the `<Subdomain>.Repo` sandbox and provides Ecto imports + `Phoenix.ConnTest` macros (`build_conn`, `post`, `get`, `json_response`).

#### Request Helpers (`SportipediaWeb.RequestHelpers`)

Import at the top of your test module. All provided by the project:

| Helper                                                 | Purpose                                                        |
| ------------------------------------------------------ | -------------------------------------------------------------- |
| `authenticate_conn(conn, user \\ %{id: UUID.uuid4()})` | Sets `conn.assigns.user` for Bodyguard auth bypass             |
| `api_conn(conn)`                                       | Sets `Content-Type: application/vnd.api+json`                  |
| `jsonapi_body(type, attrs)`                            | Builds `%{"data" => %{"type" => type, "attributes" => attrs}}` |
| `jsonapi_body(type, attrs, id)`                        | Also includes `"id"` in the data object                        |
| `jsonapi_id(response)`                                 | `response["data"]["id"]`                                       |
| `jsonapi_type(response)`                               | `response["data"]["type"]`                                     |
| `jsonapi_attrs(response)`                              | `response["data"]["attributes"]`                               |
| `jsonapi_attr(response, field)`                        | `response["data"]["attributes"][field]`                        |

#### Sending Requests

Always use `api_conn()` + `Jason.encode!()` with `post` or `get`:

```elixir
conn =
  build_conn()
  |> authenticate_conn()
  |> api_conn()
  |> post("/<-subdomain>/<-composite>/<domain-object>s/<-action>",
    Jason.encode!(jsonapi_body("<jsonapi-type>", %{...}))
  )

body = json_response(conn, 200)
```

For requests that need an explicit `id` in the body (edit, archive), use the 3-arg form:

```elixir
jsonapi_body("<jsonapi-type>", %{...}, id)
```

The `JSONAPI.Deserializer` plug flattens `data.id` and `data.attributes.*` into `conn.params`. So `data.id` becomes `conn.params["id"]`.

#### Auth Pattern

Bodyguard reads `conn.assigns.user` via `Auth.get_user_from_assigns/1`. The Guardian pipeline in the `:catalog` pipeline has `allow_blank: true`, so it passes through without error when no token is present.

- **Authenticated:** call `authenticate_conn(conn)` before the request
- **Unauthenticated:** send the request without calling `authenticate_conn`

The `FallbackController` returns `403` for `{:error, :unauthorized}`. Test names should match:

```elixir
test "returns 403 when unauthenticated" do
  conn =
    build_conn()
    |> api_conn()
    |> post("/path", Jason.encode!(jsonapi_body("<jsonapi-type>", %{...})))

  assert json_response(conn, 403)
end
```

#### Evaluationg Responses and (Status Code) Assertions

Asserting attributes:

```elixir
# individual attributes
assert jsonapi_attr(body, "title") == "Vault"
assert jsonapi_id(body) == some_id

# entire body
assert %{...} == body
```

For error responses, also evaluate it is the correct error format

Use `json_response(conn, expected_status)` — it raises `RuntimeError` if the actual status differs, so the `assert` wrapping is redundant.

| Code  | Usage                                                                |
| ----- | -------------------------------------------------------------------- |
| `200` | Successful                                                           |
| `204` | Successful delete/archive                                            |
| `403` | Unauthenticated (FallbackController returns 403 for `:unauthorized`) |
| `404` | Resource not found                                                   |
| `422` | Validation failure                                                   |

The Domain model has answers to what is expected behavior.

#### Test Template

```elixir
defmodule SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<Operation>EndpointTest do
  use SportipediaWeb.ConnCase
  import SportipediaWeb.RequestHelpers
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Model, as: <DomainObject>

  describe "<HTTPMethod> (<operation>)" do
    test "<happy path, everything works>" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post("/<-subdomain>/<-composite>/<domain-object>s/<-action>",
          Jason.encode!(jsonapi_body("<jsonapi-type>", %{...}))
        )

      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "<jsonapi-type>",
                 "attributes" => %{
                   ...
                 }
               }
             } = body

      assert Repo.get(<DomainObject>, id)
    end

    test "returns 403 when unauthenticated" do
      conn =
        build_conn()
        |> api_conn()
        |> post("/<-subdomain>/<-composite>/<domain-object>s/<-action>",
          Jason.encode!(jsonapi_body("<jsonapi-type>", %{...}))
        )

      assert json_response(conn, 403)
    end

    test "returns 422 when <param is wrong>" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post("/<-subdomain>/<-composite>/<domain-object>s/<-action>",
          Jason.encode!(jsonapi_body("<jsonapi-type>", %{...}))
        )

      assert json_response(conn, 422)
    end

    # more tests to cover all expected responses
  end
end
```

### Example: List Read Model with query params

Here is the example for
[`list-apparatuses`
query](../../../../domain-model/catalog/equipment/query.list-apparatuses.esdm.yaml)
showcasing testing for query params.

```elixir
    test "filters apparatuses by title (case-insensitive partial match)", %{conn: conn} do
      # Arrange: Use Public API to seed the read models
      {:ok, _a1} =
        Apparatus.catalog_apparatus(%{title: "Vaulting Table", slug: "vaulting-table"})

      {:ok, _a2} =
        Apparatus.catalog_apparatus(%{title: "Pommel Horse", slug: "pommel-horse"})

      {:ok, _a3} =
        Apparatus.catalog_apparatus(%{title: "Still Rings", slug: "still-rings"})

      # Act: Here test the query params
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses?filter[title]=vault")


      # Assert: Verify the results
      body = json_response(conn, 200)

      assert %{"data" => data} = body
      assert is_list(data)
      assert length(data) == 1
      assert jsonapi_attr(hd(data), "title") == "Vaulting Table"
    end
```
