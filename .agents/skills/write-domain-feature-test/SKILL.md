---
name: write-domain-feature-test
description: Write a vertical-slice feature test for a CQRS/ES operation in the Sportipedia catalog domain. Covers Policy, Command validation, Handler, Event, Aggregate, Projector, and End-to-end dispatch in a single test file.
---

## Test File Location

```
test/sportipedia/catalog/equipment/<entity>/features/<feature_name>_test.exs
```

## Test Module Pattern

```elixir
defmodule Sportipedia.Catalog.Equipment.<Entity>.Feature.<FeatureName>Test do
  use Sportipedia.CatalogTestCase

  alias Sportipedia.Catalog.Equipment.<Entity>
  alias Sportipedia.Catalog.Equipment.<Entity>.Policy
  alias Sportipedia.Catalog.Equipment.<Entity>.Command.<FeatureName>
  alias Sportipedia.Catalog.Equipment.<Entity>.Command.<FeatureName>Handler
  alias Sportipedia.Catalog.Equipment.<Entity>.Event.<EventName>
  alias Sportipedia.Catalog.Equipment.<Entity>.Aggregate.<AggregateName>, as: Aggregate
  alias Sportipedia.Catalog.Equipment.<Entity>.ReadModel.<ReadModelName>, as: ReadModel
  alias Sportipedia.Catalog.Equipment.<Entity>.Projectors.<ProjectorName>
  alias Sportopedia.Catalog.Repo
```

## Describe Blocks

### 1. Policy

Tests `Policy.authorize/3` — pure function, tag as `:unit`.

| Action          | Test             | Pattern                                                 |
| --------------- | ---------------- | ------------------------------------------------------- |
| Authenticated   | returns `:ok`    | `Policy.authorize(:<action>, %{id: "uid"}, %{}) == :ok` |
| Unauthenticated | returns `:error` | `Policy.authorize(:<action>, nil, %{}) == :error`       |

### 2. Command validation

Tests Vex validators. Pure Vex tests are `:unit`; tests needing the DB (e.g. uniqueness checks) are `:integration`.

- Call `Command.new(attrs)` — uses `ExConstructor`
- Assert `Vex.valid?(command)` or `refute Vex.valid?(command)`
- Assert specific errors: `Enum.any?(Vex.errors(cmd), &match?({:error, :field, _, _}, &1))`
- For uniqueness: insert into `Catalog.Repo` first, then assert Vex error with the exact message

### 3. Handler

Tests `Handler.handle/2` — pure function, tag as `:unit`.

```elixir
test "creates <Event> from <Command>" do
  cmd = <Command>.new(...)
  event = <Command>Handler.handle(%Aggregate{}, cmd)
  assert %<Event>{...} = event
end
```

### 4. Event

Tests event struct and serialization — pure, tag as `:unit`.

- Struct creation with enforced fields
- `Jason.encode!(event)` — verify serialization
- If the event has a `get_changes/1` helper, test it filters nil values

### 5. Aggregate

Tests `Aggregate.apply/2` for the specific event — pure, tag as `:unit`.

```elixir
test "applies <Event> to aggregate state" do
  event = %<Event>{...}
  result = Aggregate.apply(%Aggregate{}, event)
  assert result.field == value
end
```

### 6. Projector

Tests the projection logic by calling the projector's `handle/2` directly — needs DB, tag as `:integration`.

The `project` macro in `projector.ex` generates a `handle(event, metadata)` function clause. Call it with the event and a metadata map containing at least `:handler_name` (matches the `:name` option in `use Commanded.Projections.Ecto`) and `:event_number` (unique non-negative integer):

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

### 7. End-to-end

Tests the full dispatch through `Sportipedia.Catalog` — needs event store (InMemory) and DB, tag as `:integration`.

| Test               | Pattern                                                                                                                            |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| Dispatch success   | `assert :ok = Sportipedia.Catalog.dispatch(cmd, consistency: :strong)` then `assert %ReadModel{...} = Repo.get(ReadModel, cmd.id)` |
| Validation failure | `assert {:error, {:validation_failure, %{field: [message]}}} = Sportipedia.Catalog.dispatch(cmd)`                                  |
| Public API         | Call `<Entity>.<action>(params)` and assert `{:ok, result}`                                                                        |

## Tagging Convention

```elixir
@tag :unit        # pure logic, no DB or event store
@tag :integration # needs Catalog.Repo DB or Commanded event store
```

## Implementation Notes

- Commands use `ExConstructor` for construction: `<Command>.new(attrs)`
- Errors from `Sportipedia.Catalog.dispatch` go through the `Validate` middleware which merges Vex errors into `%{field: [message]}`
- Vex presence validator message: `"must be present"`
- Ecto `unique_constraint` message from DB: `"has already been taken"`
- Ecto.Multi error tuples: `{:error, :multi_name, changeset, effects}`
- The aggregate `id` may not be propagated from the event — Commanded manages identity separately via the router's `identify` macro
