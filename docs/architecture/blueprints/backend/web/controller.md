# Controller

Blueprint for a phoenix controller implementing the request to an operation in
the Sportipedia domain.

| --- | --- |
| File Path | `/services/api/lib/sportipedia_web/<_subdomain>/<_composite>/<domain_object>/controller.ex` |
| Module Name | `Sportipedia.Catalog.<Composite>.<DomainObject>Controller` |
| Test File | `/services/api/test/sportipedia/catalog/<_composite>/<domain_object>/operation/<_operation>_test.exs` |
| Test Module Name | `Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test` |

## Implementation

A phoenix controller.

- `use SportipediaWeb, :controller`
- `use OpenApiSpex.ControllerSpecs`

### Empty Controller Template

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

### Collection Endpoints

For collection endpoints, that offer filtering and paging, it needs to be specified by which fields they can do this:

```elixir
  plug JSONAPI.QueryParser,
    filter: ~w(<_field>),
    sort: ~w(<_field>),
    view: <DomainObject>View
```

### Operation Endpoints

Each endpoint has an `operation` with function to it.

- `operation :<_operation>` for the open API specs
- Take fitting descriptions from domain model
- An `<_operation>` may result in a create, read, update or delete database operation. Find a template for each below.

#### Create Operation

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

#### Read ReadModel Operation

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

#### Read Collection Operation

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

#### Udpate Operation

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

#### Delete Operation

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

Use the controller from the router.

File Location: `/services/api/lib/sportipedia_web/router.ex`

Sets route for the operation, there are only two verbs allowed:

- `GET`: queries / read operation
- `POST`: commands / write operation

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

Assumption: The `:<_subdomain>` pipeline is given

## Test

see [Endpoint Test](./endpoint-test.md)
