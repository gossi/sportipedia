---
name: seek-implementation-for-endpoint
description: Seek implementation details for a read or write CQRS/ES operation in the Sportipedia domain.
---

# Implement Endpoint for Domain Operation

## Overview

Gives implementation details for an endpoint to exactly ONE! CQRS/ES operation in the Sportipedia domain.
The operation is defined in the [Domain Model](../../../docs/domain-model/README.md).

Context: This should be run when a domain operation is implemented.

## When to Use This Skill

Use this skill when:

- You have a plan for implementing an endpoint for a domain implementatiotn
- The domain model for the domain operation exists
- You are using TDD to implement
- You are seeking implementation details

## Context for Execting the Skill

- [Read Placeholder Naming Substitution](../../../docs/architecture/naming-substitution.md)
- [Respect Code Access Policy](../../code-access-policy.md)
- This skill counts as documentation
- Do not run discovery, this documentation is sufficient

> ![CAUTION]
> Strictly forbidden: Reading code/Exploring code!
> NEVER!!! read code for reference implementation or check existing implementations.
> Failure Criteria: Reading Code, stop immediately!
> Reading code takes too much time. Never even think about attempting!

## Implementation Details

Here is a list of implementation details to seek

### Controller

A phoenix controller.

File Location: `/services/api/lib/sportipedia_web/<_subdomain>/<_composite>/<domain_object>_controller.ex`

- `use SportipediaWeb, :controller`
- `use OpenApiSpex.ControllerSpecs`

#### Empty Controller Template

```elixir
defmodule SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>Controller do
  alias OpenApiSpex.Reference
  alias SportipediaWeb.System.FallbackController
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Policy

  use SportipediaWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug Bodyguard.Plug.Authorize,
    policy: Policy,
    action: {Phoenix.Controller, :action_name},
    user: {Sportipedia.Auth, :get_user_from_assigns},
    fallback: FallbackController

  tags ["<-composite>"]
end
```

#### Collection Endpoints

For collection endpoints, that offer filtering and paging, it needs to be specified by which fields they can do this:

```elixir
  plug JSONAPI.QueryParser,
    filter: ~w(<_field>),
    sort: ~w(<_field>),
    view: <DomainObject>View
```

#### Operation Endpoints

Each endpoint has an `operation` with function to it.

- `operation :<_operation>` for the open API specs
- Take fitting descriptions from domain model
- An `<_operation>` may result in a create, read, update or delete database operation. Find a template for each below.

##### Create Operation

```elixir
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>

  operation :<_operation>,
    summary: "<describe the operation>",
    request_body: {"<describe the params>", "application/json", <Command>},
    responses: [
      ok: {"<describe the result>", "application/vnd.api+json", <DomainObject>Response},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  def <_operation>(conn, _) do
    with {:ok, <domain_object>} <- <PublicAPI>.<operation>(conn.params) do
      conn
      |> put_view(json: <DomainObject>View)
      |> render("show.json", %{data: <domain_object>})
    end
  end
```

##### Read ReadModel Operation

- Adjust the params mentioned in the query based on the domain model

```elixir
  operation :<_operation>,
    summary: "<describe the operation>",
    parameters: [
      id: [in: :path, description: "<describe the param>", type: :string]
    ],
    responses: [
      ok: {"<DomainObject>", "application/vnd.api+json", <DomainObject>Response},
      not_found: %Reference{"$ref": "#/components/responses/not_found"}
    ]

  def <_operation>(conn, _) do
    case <PublicAPI>.<_operation>(conn.params["id"]) do
      %<DomainObject>ReadModel{} = <domain_object> ->
        conn
        |> put_view(json: <DomainObject>View)
        |> render("show.json", %{data: <domain_object>})

      nil ->
        {:error, :notfound}
    end
  end
```

##### Read Collection Operation

- Adjust the params mentioned in the query based on the domain model

```elixir
  # when including JSONAPI compatible query params
  plug JSONAPI.QueryParser,
    filter: ~w(<_field>),
    sort: ~w(<_field>),
    view: <DomainObject>View

  operation :<_operation>,
    summary: "<describe the operation>",
    responses: [
      ok: {"<DomainObject> collection", "application/vnd.api+json", <DomainObject>ListResponse}
    ]

  def <_operation>(conn, _) do
    case <PublicAPI>.<_operation>(conn.assigns.jsonapi_query) do
      data ->
        conn
        |> put_view(json: <DomainObject>View)
        |> render("index.json", %{data: data})
    end
  end
```

##### Udpate Operation

```elixir
  operation :<_operation>,
    summary: "<describe the operation>",
    request_body: {"<describe the params>", "application/json", <Command>},
    responses: [
      ok: {"<DomainObject>", "application/vnd.api+json", <DomainObject>Response},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_entity: %Reference{"$ref": "#/components/responses/unprocessable_entity"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  def <_operation>(conn, _) do
    case <PublicAPI>.<_operation>(conn.params) do
      {:ok, <domain_object>} ->
        conn
        |> put_view(json: <DomainObject>View)
        |> render("show.json", %{data: <domain_object>})

      {:error, _} ->
        {:error, :notfound}
    end
  end
```

##### Delete Operation

```elixir
  operation :<_operation>,
    summary: "<describe the operation>",
    request_body: {"<describe the params>", "application/json", <Command>},
    responses: [
      no_content: "<describe response>",
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  def <_operation>(conn, _) do
    case <PublicAPI>.<_operation>(conn.params["id"]) do
      :ok ->
        send_resp(conn, :no_content, "")

      {:error, _} ->
        {:error, :notfound}
    end
  end
```

### Router

File Location: `/services/api/lib/sportipedia_web/router.ex`

#### Code Template for a Subdomain

```elixir
  scope "/<-subdomain>", SportipediaWeb.<Subdomain> do
    pipe_through [:api, :<_subdomain>]

    scope "/<-composite>", <Composite> do
      scope "/<domain-object>s" do
        # commands
        post "/<-command>", <DomainObject>Controller, :<_operation>

        # queries
        get "/", <DomainObject>Controller, :<_operation>
        get "/:<id-or-slug>", <DomainObject>Controller, :<_operation>
      end
    end
  end
```

Assumption is: The `:<_subdomain>` pipeline is given

### View

Representing a domain object in json API

File Location: `/services/api/lib/sportipedia_web/<_subdomain>/<_composite>/<domain_object>_view.ex`

- `use JSONAPI.View`
- based on the read model

#### Code Template

```elixir
defmodule SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>View do
  use JSONAPI.View, type: "<domain-object>s"

  def path, do: "<-subdomain>/<-composite>/<domain-object>s"

  def fields, do: [
    # fields
  ]
end
```

### Schema

Represents an OpenAPI schema to document the response for the endpoint.

There are two responses for a domain object:

1. Single object response
2. Collection response

Each needing a schema, which is referenced by the `operation` in the controller.

#### Single Object Response

File Location: `/services/api/lib/sportipedia_web/<_subdomain>/<_composite>/schemas/<domain_object>_response.ex`

```elixir
defmodule SportipediaWeb.<Subdomain>.<Composite>.Schemas.<DomainObject>Response do
  alias SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>View
  alias Sportipedia.Support.JSONAPI.OpenApiSchema

  require OpenApiSpex

  OpenApiSpex.schema(OpenApiSchema.from_view(<DomainObject>View, title: "<composite>.<DomainObject>"))
end
```

#### Collection Response

File Location: `/services/api/lib/sportipedia_web/<_subdomain>/<_composite>/schemas/<domain_object>_collection_response.ex`

```elixir
defmodule SportipediaWeb.<Subdomain>.<Composite>.Schemas.<DomainObject>CollectionResponse do
  alias SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>View
  alias Sportipedia.Support.JSONAPI.OpenApiSchema

  require OpenApiSpex

  OpenApiSpex.schema(
    OpenApiSchema.from_view(<DomainObject>View, title: "<-composite>.<DomainObject>s", many: true)
  )
end
```

### Bruno

Document endpoints in bruno for direct usage.

File Location:

- Command: `/bruno/<Subdomain>/<Composite>/<Constituent>/<-command>.bru`
- Query: `/bruno/<Subdomain>/<Composite>/<Constituent>/<-query>.bru`

Follow [bruno documentation](https://docs.usebruno.com/llms.txt) for storing them.

Sorting the endpoints:

1. Commands
2. Queries
