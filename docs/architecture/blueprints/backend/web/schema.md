# Scheme

| Attribute        | Value                                                                                                         |
| ---------------- | ------------------------------------------------------------------------------------------------------------- |
| File Path        | `/services/api/lib/sportipedia_web/<_subdomain>/<_composite>/<domain_object>/schemas/<operation>_response.ex` |
| Module Name      | `SportipediaWeb.<Subdomain>.<Composite>.Schemas.<Operation>Response`                                          |
| Test File Path   | `test/sportipedia_web/<_subdomain>/<_composite>/<domain_object>/<domain_object>_schema_test.exs`              |
| Test Module Name | `SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>ViewTest`                                               |

Blueprint for a schema used to document a read model in JSONAPI.

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the command
  rsp. query/read model

## Implementation

Represents an OpenAPI schema to document the schema for the endpoint.

- Use `OpenApiSpex`
- One schema per operation:
  - Command
    1. Single object response
    2. Collection response
  - Query
- The schema is referenced by the `operation` in the controller
- There is no need to register the schema in API spec. Using them in the controller is enough.

### Implementation Template

```elixir
defmodule SportipediaWeb.<Subdomain>.<Composite>.Schemas.<DomainObject>Response do
  require OpenApiSpex

  OpenApiSpex.schema(%{...})
end
```

### Example: Single Object Response Query

A query returning a single read model will use this template
Using the [view](./view.md).

```elixir
defmodule SportipediaWeb.<Subdomain>.<Composite>.Schemas.<DomainObject>Response do
  alias SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>View
  alias Sportipedia.Support.JSONAPI.OpenApiSchema

  require OpenApiSpex

  OpenApiSpex.schema(OpenApiSchema.from_view(<DomainObject>View, title: "<composite>.<DomainObject>"))
end
```

### Example: Collection Response Query

A query returning a read model collection will use this template.
Using the [view](./view.md).

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

### Example: Commands

The [Domain Model](../../../../domain-model/README.md) for the given command has
all the details needed to generate the schema from it.

One Caveat: When the command result in a database CREATE operation, the id can
be skipped from the parameters. It will be auto-generated as part of the [public API](../domain/public-api.md#example-create-command-id)

## Test

Use `use ExUnit.Case` (no DB, no sandbox). Test that the compile-time schema has the expected structure:

### Test Template

```elixir
defmodule SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>SchemaTest do
  use ExUnit.Case

  alias SportipediaWeb.<Subdomain>.<Composite>.Schemas.<DomainObject>Response

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
