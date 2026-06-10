# Public API

| Attribute | Value |
| --- | --- |
| File Path | `/services/api/lib/sportipedia/<_subdomain>/<_composite>/<domain_object>/public_api.ex` |
| Module Name | `Sportipedia.<Subdomain>.<Composite>.<DomainObject>` |
| Test | See [Operation Test](./operation-test.md) |

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the command or query

## Implementation

What it contains:

- Exactly one function per operation, that is found in the domain model
  - One function per command operation
  - One function per query operation

What it does not contain:

- Functions, that live in the [internal API](./internal-api.md)

### Command

- Dispatches the command with `consistency: :strong` (no other options)
- Validation handling:
  - Vex runs as commanded middleware and validates the command
  - No extra code needed
  - No try ... rescue
  - call the dispatch with `with {:ok, read_model} <- Catalog.dispatch()` - that way the error from vex validation
    is returned
  - No param matching, that would hide the error we want to return
- If the command results in a CREATE projection, instantiate a UUID for it (see
  example below)
- If the command addresses a read model, return it
  - Try internal API for fetching it, fallback to using `Repo`
  - Unless the command resuslts in DELETE projection, then don't (see example below)

### Query

Query Ecto for the read model

- read one read model: try [Internal API](./internal-api.md) fallback to `Repo.get`
- list many read models: use `Repo.all` with
  `Sportipedia.Support.JSONAPI.QueryBuilder` (see example below)
- all others:
  - may use internal API for partial query
  - use the respective custom query

If the params to the query are `oneOf`, then the params should reflect this, eg: `def <_operation>(id_or_slug) do`.
Identify this as part of the implementation where to query. Use as much private function as it needs

### Return Types

Return types for public functions is:

- With result: `Sportipedia.Architecture.public_api_with_result()`
- Without result: `Sportipedia.Architecture.public_api()`

### Implementation Template

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject> do
  def <_operation>(params) do
    # implementation logic
  end
end
```

### Example: Create Command ID

Here the command results in a DB CREATE projection, thus we create the UUID and
later query the [internal API](./internal-api.md).

```elixir
  def <_operation>(params) do
    id = UUID.uuid4()
    cmd = <Command>.new(Map.put(params, :id, id))

    with {:ok, aggregate} <-
           Catalog.dispatch(cmd, consistency: :strong) do
      {:ok, <DomainObject>Internal.<domain_object>_by_id(id)}
    end
  end
```

### Example: Query with JSONAPI query

We expect a JSONAPI query as param.

```elixir
  def list_instruments(query) do
    Repo.all(QueryBuilder.build(query, InstrumentReadModel))
  end
```

### Example: Command resulting in a database `DELETE` operation

Here we return if the command dispatch was handled correctly.

```elixir
  def archive_instrument(id) do
    Catalog.dispatch(ArchiveInstrument.new(id: id), consistency: :strong)
  end
```

## Test

Tests the public API — needs event store (InMemory) and DB and all relevant public API call.

- test success
- test validation (response is: `{:error, Sportipedia.Architecture.validaton_failures()}`)
- test failures
