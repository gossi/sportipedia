---
name: write-domain-feature-test
description: Write a vertical-slice feature test for a CQRS/ES operation in the Sportipedia catalog domain. Covers Policy, Command validation, Handler, Event, Aggregate, Projector, and End-to-end dispatch in a single test file.
---

## Must Read: Guidelines

- [Architecture](../../../ARCHITECTURE.md)
- [Coding Guidelines](../../../docs/coding-guidelines/README.md)

## Test File Location

```
test/sportipedia/catalog/<subdomain>/<entity>/features/<feature_name>_test.exs
```

## Test Module Pattern

```elixir
defmodule Sportipedia.Catalog.<Composite>.<DomainObject>.Feature.<FeatureName>Test do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.<Composite>.<DomainObject>
  alias Sportipedia.Catalog.<Composite>.<DomainObject>.Policy
  alias Sportipedia.Catalog.<Composite>.<DomainObject>.Command.<FeatureName>
  alias Sportipedia.Catalog.<Composite>.<DomainObject>.Command.<FeatureName>Handler
  alias Sportipedia.Catalog.<Composite>.<DomainObject>.Event.<EventName>
  alias Sportipedia.Catalog.<Composite>.<DomainObject>.<AggregateName>
  alias Sportipedia.Catalog.<Composite>.<DomainObject>.<ReadModelName>
  alias Sportipedia.Catalog.<Composite>.<DomainObject>.<ProjectorName>
  alias Sportopedia.Catalog.Repo
```

## Test Contents

The test may (if applicable) cover the following:

- Policy
- Command
- Command Handler
- Event
- Event Handler
- Aggregate
- Projector
- End-to-End

Each is represented as a `describe` block in the test file and explained below.

### Policy

Tests `Policy.authorize/3` — pure function

### Command

- Struct creation with enforced fields
- Validation

### Handler

Tests the command handlers, input into output. Ideally pure, integration tests when needed.

### Event

Tests events.

- Test against invalid struct creation (missing enforced fields)
- Serialization, via `Jason.encode!(event)`

### Event Handler

tbd.

### Aggregate

Tests `Aggregate.apply/2` for the specific event.

```elixir
test "applies <Event> to aggregate state" do
  event = %<Event>{...}
  result = Aggregate.apply(%Aggregate{}, event)
  assert result.field == value
end
```

### Projector

Tests the projection logic by calling the projector's `handle/2` directly — needs DB.

The `project` macro in `projector.ex` generates a `handle(event, metadata)` function clause. Call it with the event and a metadata map containing at least `:handler_name` (matches the `:name` option in `use Commanded.Projections.Ecto`) and `:event_number` (unique non-negative integer).

Example:

```elixir
metadata = %{
  handler_name: "<projection_name>",
  event_number: 1,
  event_id: UUID.uuid4(),
  stream_id: "entity-#{event.id}",
  stream_version: 1,
  correlation_id: nil,
  causation_id: nil,
  created_at: DateTime.utc_now(),
  application: Sportipedia.Catalog,
  state: nil
}
```

**Success case:**

```elixir
assert :ok = <ProjectorName>.handle(event, metadata)

record = Repo.get!(ReadModel, event.id)
assert record.field == expected
```

**Idempotency case** (same `event_number` is skipped via `ProjectionVersion`):

```elixir
assert :ok = <ProjectorName>.handle(event, metadata)
assert :ok = <ProjectorName>.handle(event, metadata)

assert [record] = Repo.all(ReadModel)
```

**Error case** (e.g. DB constraint violation):

```elixir
assert {:error, _} = <ProjectorName>.handle(event, metadata)
```

### End-to-end

Tests the full dispatch through `Sportipedia.Catalog` — needs event store (InMemory) and DB and all relevant public API call.

| Test               | Pattern                                                                                                                            |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| Dispatch success   | `assert :ok = Sportipedia.Catalog.dispatch(cmd, consistency: :strong)` then `assert %ReadModel{...} = Repo.get(ReadModel, cmd.id)` |
| Validation failure | `assert {:error, {:validation_failure, %{field: [message]}}} = Sportipedia.Catalog.dispatch(cmd)`                                  |
| Public API         | Call `<DomainObject>.<action>(params)` and assert `{:ok, result}`                                                                  |

## Implementation Notes

- Commands use `ExConstructor` for construction: `<Command>.new(attrs)`
- Errors from `Sportipedia.Catalog.dispatch` go through the `Validate` middleware which merges Vex errors into `%{field: [message]}`
- Vex presence validator message: `"must be present"`
- Ecto `unique_constraint` message from DB: `"has already been taken"`
- Ecto.Multi error tuples: `{:error, :multi_name, changeset, effects}`
