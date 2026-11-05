---
generator: "mix sp.gen.schema <element>"
blueprints:
  - SpGen.Blueprint.Schema
  - SpGen.Blueprint.SchemaTest
module: "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.Schemas.<Name>"
writes: [module, schema test]
---

# Schema

OpenAPI documents for the endpoint: the request body, the response envelope, the
query parameters. `OpenApiSpex` modules, referenced from the controller's
`operation`; there is nothing to register in the API spec — using them is the
registration.

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the command,
  query or read model.
- The [public API](../domain/public-api.md) function exists — its `@spec` is the
  shape a response schema is derived from.

## What the generator does

By element kind (the `--template` is derived, as everywhere):

| Element | Schema files |
| --- | --- |
| read model | `<DomainObject>Response` and `<DomainObject>CollectionResponse`, both built from the JSON:API view (`Sportipedia.Support.JSONAPI.OpenApiSchema`) |
| command (`create`, `update`) | `<Command>Request` from the command's data fields |
| command (`delete`) | none — the id rides in the body as `data.id` |
| query (collection, with `parameters`) | `<Operation>QueryParams` from the query's filter fields, sort and the standard JSON:API `page`/`fields` |

Two rules worth knowing because they are easy to get wrong by hand:

- A **create** request never carries `id`: the public API generates it.
- Types follow the model, not the Elixir struct: `string`/`uuid` → `:string`
  with the format, `integer` → `:integer`, nullable when the field is optional.

## Tests

Each schema module gets its own ExUnit test file (`use ExUnit.Case`, no DB, no
sandbox) asserting the structure of `schema/0`: its title
(`<composite>.<SchemaName>`) and that it is an object. Behaviour is asserted at
the [endpoint](./endpoint-test.md), not in the schema.
