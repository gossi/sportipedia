---
name: seek-implementation-for-endpoint-test
description: Write a vertical-slice endpoint test for a controller action in the Sportipedia catalog web layer. Covers the controller endpoint, view rendering, and OpenAPI schemas for one feature. Use when the user asks you to write tests for an HTTP endpoint.
---

# Implement Endpoint for Domain Operation Test

## Overview

Gives implementation details for testing an endpoint to exactly ONE! CQRS/ES operation in the Sportipedia domain.
The operation is defined in the [Domain Model](../../../docs/domain-model/README.md).

Context: This should be run when an endpoint for a domain operation is implemented.

## When to Use This Skill

Use this skill when:

- You have a plan for implementing an endpoint for a domain operation
- The endpoint is known
- You are using TDD to implement
- You are about to write a test
- You are seeking a way to structure the test file
- You need to know what you want/need to test

## Context for Execting the Skill

- [Read Placeholder Naming Substitution](../../../docs/architecture/naming-substitution.md)
- [Respect Code Access Policy](../../code-access-policy.md)
- [Respect Coding Guidelines](../../../docs/coding-guidelines/README.md)
- This skill counts as documentation
- DO not run discovery, this documentation is sufficient

### Before You Start — Mandatory Checklist

Answer these questions BEFORE writing any code. If any answer is "no" or "unsure", STOP and ask.

- [ ] Do I know EXACTLY which operation I'm implementing? (single command or query name)
- [ ] Do I have the domain model files for this operation?
- [ ] Can I list every file I need to create from the skill templates alone?
- [ ] Do I have everything I need from documentation? (no code exploration required)

### Code Templates

- Code Templates give you a scaffolding, when creating the file from scratch
- They are templates, not strict guidelines
- Sorting functions in modules when they contain both queries and commands:
  1. All commands
  2. All queries

## Test Contents

- The [Domain Model](../../../docs/domain-model/README.md) contains the operation but also its behavior and/or test instructions.

## Implementation Details

The test may (if applicable) cover the following:

- Request
- Views
- Schema

### Request Test

File Location: `test/sportipedia_web/<_subdomain>/<_composite>/<_constituent>/operation/<_operation>_request_test.exs`

One file per operation (e.g. `catalog_instrument_request_test.exs`, `edit_instrument_request_test.exs`).

#### Test Module Pattern

```elixir
defmodule SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<Operation>RequestTest do
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

  json_response(conn, 403)
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

#### Code Template

```elixir
defmodule SportipediaWeb.<Subdomain>.<DomainObject>.<Operation>EndpointTest do
  use SportipediaWeb.ConnCase
  import SportipediaWeb.RequestHelpers
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Model, as: <DomainObject>

  @tag :integration
  describe "<HTTPMethod> <operation>" do
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

### View Tests

File Location: `test/sportipedia_web/<_subdomain>/<_composite>/<_constituent>/<domain_object>_view_test.exs`

View unit tests are in a `describe "View"` block alongside the controller tests. The JSONAPI View's `render` function requires a `Plug.Conn` struct with fetched params:

Also test `type/0`, `fields/0`, `path/0` as unit tests.

#### Code Template

```elixir
defmodule SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>ViewTest do
  use SportipediaWeb.ConnCase

  alias SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>View
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>ReadModel

  import SportipediaWeb.RequestHelpers

  describe "View" do
    test "render show.json produces JSON:API single document" do
      <domain_object> = %<DomainObject>{...}
      conn = build_conn() |> fetch_query_params()
      result = <DomainObject>View.render("show.json", %{data: <domain_object>, conn: conn})

      assert %{data: %{id: _, type: "<jsonapi-type>", attributes: %{...}}} = result
    end
  end
end
```

### OpenAPI Schema Tests

File Location: `test/sportipedia_web/<_subdomain>/<_composite>/<_constituent>/<domain_object>_schema_test.exs`

Use `use ExUnit.Case` (no DB, no sandbox). Test that the compile-time schema has the expected structure:

#### Code Template

```elixir
defmodule SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>SchemaTest do
  use ExUnit.Case

  alias SportipediaWeb.<Subdomain>.<Composite>.Schemas.<DomainObject>Response

  @tag :unit
  describe "<DomainObject>Response" do
    test "schema/0 has the correct title" do
      assert %{title: "<_composite>.<DomainObject>"} = <DomainObject>Response.schema()
    end

    test "schema has data with id, type, and attributes" do
      schema = <DomainObject>Response.schema()
      data_props = schema.properties.data.properties
      assert Map.has_key?(data_props, :id)
      assert Map.has_key?(data_props, :type)
      assert Map.has_key?(data_props, :attributes)
    end
  end
end
```

## Test Guidelines

### Covering Functionality

Apply both:

- Positive testing: verifies that the system works as expected with valid inputs.
- Negative testing: checks how the system handles invalid, unexpected, or edge-case inputs.

### Writing Tests

- Follow the tagging conventions from [Elixir Coding Guidelines](../../../docs/coding-guidelines/elixir.md)
- Follow the naming conventions from [Naming Conventions](../../../docs/coding-guidelines/naming-conventions.md)
  - When comparing to other tests, rank the convention guidelines higher than existing source code

## Verification — Before Declaring Done

Check each item. If any is "no", you have scope creep:

- [ ] Did I create files ONLY for the named operation?
- [ ] Did I read any implementation files? (should be: no)
- [ ] Did I follow directory structure from docs, not from existing code?
