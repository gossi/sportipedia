---
name: implement-request-test
description: Write a vertical-slice request test for a controller action in the Sportipedia catalog web layer. Covers the controller endpoint, view rendering, and OpenAPI schemas for one feature. Use when the user asks you to write tests for an HTTP endpoint.
---

## File Location

```
test/sportipedia_web/catalog/<subdomain>/<feature_name>_request_test.exs
```

One file per request type (e.g. `catalog_instrument_request_test.exs`, `edit_instrument_request_test.exs`).

## Test Module Pattern

```elixir
defmodule SportipediaWeb.Catalog.<Subdomain>.<FeatureName>RequestTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.<Subdomain>.<Entity>.<ReadModelName>
  alias SportipediaWeb.Catalog.<Subdomain>.<Entity>View
end
```

`SportipediaWeb.ConnCase` manages the `Catalog.Repo` sandbox and provides Ecto imports + `Phoenix.ConnTest` macros (`build_conn`, `post`, `get`, `json_response`).

## Request Helpers (`SportipediaWeb.RequestHelpers`)

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

## Sending Requests

Always use `api_conn()` + `Jason.encode!()` with `post`:

```elixir
conn =
  build_conn()
  |> authenticate_conn()
  |> api_conn()
  |> post("/catalog/<subdomain>/<domain-object>s/<action>",
    Jason.encode!(jsonapi_body("<type>", %{field: "value"}))
  )

body = json_response(conn, 200)

# Access response fields via helpers
assert jsonapi_attr(body, "title") == "Vault"
assert jsonapi_id(body) == some_id
```

For requests that need an explicit `id` in the body (edit, archive), use the 3-arg form:

```elixir
jsonapi_body("<type>", %{title: "Updated"}, instrument_id)
```

The `JSONAPI.Deserializer` plug flattens `data.id` and `data.attributes.*` into `conn.params`. So `data.id` becomes `conn.params["id"]`.

## Auth Pattern

Bodyguard reads `conn.assigns.user` via `Auth.get_user_from_assigns/1`. The Guardian pipeline in the `:catalog` pipeline has `allow_blank: true`, so it passes through without error when no token is present.

- **Authenticated:** call `authenticate_conn(conn)` before the request
- **Unauthenticated:** send the request without calling `authenticate_conn`

The `FallbackController` returns `403` for `{:error, :unauthorized}`. Test names should match:

```elixir
test "returns 403 when unauthenticated" do
  conn =
    build_conn()
    |> api_conn()
    |> post("/path", Jason.encode!(jsonapi_body("type", %{title: "X"})))

  json_response(conn, 403)
end
```

## Status Code Assertions

Use `json_response(conn, expected_status)` — it raises `RuntimeError` if the actual status differs, so the `assert` wrapping is redundant.

| Code  | Usage                                                                |
| ----- | -------------------------------------------------------------------- |
| `200` | Successful                                                           |
| `204` | Successful delete/archive                                            |
| `403` | Unauthenticated (FallbackController returns 403 for `:unauthorized`) |
| `404` | Resource not found                                                   |
| `422` | Validation failure                                                   |

## Tagging Convention

See [docs/guidelines/backend.md](../docs/guidelines/backend.md#tagging-convention) for tag definitions (`:unit`, `:integration`) and placement rules (`@moduletag`, `@describetag`, `@tag`).

## View Tests

View unit tests are in a `describe "View"` block alongside the controller tests. The JSONAPI View's `render` function requires a `Plug.Conn` struct with fetched params:

```elixir
@tag :unit
describe "View" do
  test "render show.json produces JSON:API single document" do
    instrument = %Instrument{...}
    conn = build_conn() |> fetch_query_params()
    result = InstrumentView.render("show.json", %{data: instrument, conn: conn})

    assert %{data: %{id: _, type: "instruments", attributes: %{title: "Vault"}}} = result
  end
end
```

Also test `type/0`, `fields/0`, `path/0` as unit tests.

## OpenAPI Schema Tests

Use `use ExUnit.Case` (no DB, no sandbox). Test that the compile-time schema has the expected structure:

```elixir
defmodule SportipediaWeb.Catalog.Equipment.InstrumentSchemaTest do
  use ExUnit.Case

  alias SportipediaWeb.Catalog.Equipment.Schemas.InstrumentResponse

  @tag :unit
  describe "InstrumentResponse" do
    test "schema/0 has the correct title" do
      assert %{title: "equipment.Instrument"} = InstrumentResponse.schema()
    end

    test "schema has data with id, type, and attributes" do
      schema = InstrumentResponse.schema()
      data_props = schema.properties.data.properties
      assert Map.has_key?(data_props, :id)
      assert Map.has_key?(data_props, :type)
      assert Map.has_key?(data_props, :attributes)
    end
  end
end
```

## Known Behaviours to Test Against

| Action             | Edge case                                | Actual behaviour                       | Reason                                                                                   |
| ------------------ | ---------------------------------------- | -------------------------------------- | ---------------------------------------------------------------------------------------- |
| edit-instrument    | Non-existent id                          | Returns `200` with null data (not 404) | Command always dispatches; `instrument_by_id` returns nil, controller renders nil as 200 |
| edit-instrument    | Validation failure (e.g. duplicate slug) | Returns `404` (not 422)                | Controller maps all `{:error, _}` to `:notfound`                                         |
| archive-instrument | Non-existent id                          | Returns `204` (not 404)                | Command always dispatches; no existence check                                            |

These are implementation quirks in the controller — test the actual behaviour, not what you think it should be.

## Typical Test Layout Per Feature

```elixir
defmodule SportipediaWeb.Catalog.Equipment.CatalogInstrumentRequestTest do
  use SportipediaWeb.ConnCase
  import SportipediaWeb.RequestHelpers
  alias Sportipedia.Catalog.Equipment.Instruments.InstrumentReadModel, as: Instrument

  @tag :integration
  describe "POST catalog-instrument" do
    test "creates instrument when authenticated" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/instruments/catalog-instrument",
          Jason.encode!(jsonapi_body("instruments", %{title: "Vault", slug: "vault"}))
        )

      body = json_response(conn, 200)
      assert jsonapi_attr(body, "title") == "Vault"
      assert Repo.get(Instrument, jsonapi_id(body))
    end

    test "returns 403 when unauthenticated" do
      conn =
        build_conn()
        |> api_conn()
        |> post("/catalog/equipment/instruments/catalog-instrument",
          Jason.encode!(jsonapi_body("instruments", %{title: "Vault", slug: "vault"}))
        )
      json_response(conn, 403)
    end

    test "returns 422 when title is missing" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/instruments/catalog-instrument",
          Jason.encode!(jsonapi_body("instruments", %{slug: "vault"}))
        )
      json_response(conn, 422)
    end
  end
end
```
