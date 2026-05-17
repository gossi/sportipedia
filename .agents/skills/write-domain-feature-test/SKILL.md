---
name: write-domain-feature-test
description: Write a vertical-slice feature test for a CQRS/ES operation in the Sportipedia domain.
---

Here is the recipe to follow (give a TODO during execution):

1. Before writing any code or tests
  - Make yourself familiar with the architecture: [Architecture](../../../ARCHITECTURE.md)
  - Understand the coding guidelins: [Coding Guidelines](../../../docs/coding-guidelines/README.md) (follow into relevant subsections)
2. Understand the code you are about to write tests for
3. Explain the Domain we are in:
  - What the feature is doing
  - What are the invariants
  - What's the domain language
3. Accumulate a list of what functionality you want to cover in the test (see section below: [Test Content](#test-contents))
4. Make a plan for how you want to write the test (respect [Test Guidelines](#test-contents))
5. Summarize the task you are about to do:
  - A technical summary for the tests to write, especially mention guidelines and conventions to respect and other constraints that apply
  - The test plan: Nested list of the describe + test block names - use the exact test names from the code to write
6. Write the tests

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

### Public API

Tests the public API — needs event store (InMemory) and DB and all relevant public API call.

- test success
- test validation (response is: `{:error, {:validation_failure, %{field: [message]}}}`)
- test failures

## Test Guidelines

Location: `test/sportipedia/catalog/<subdomain>/<entity>/features/<feature_name>_test.exs`

### Test Module Pattern

Here is an example, take it as a template:

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

### Covering Functionality

Apply both:

- Positive testing: verifies that the system works as expected with valid inputs.
- Negative testing: checks how the system handles invalid, unexpected, or edge-case inputs.

### Writing Tests

- Follow the tagging conventions from [Elixir Coding Guidelines](../../../docs/coding-guidelines/elixir.md)
- Follow the naming conventions from [Naming Conventions](../../../docs/coding-guidelines/naming-conventions.md)
  - When comparing to other tests, rank the convention guidelines higher than existing source code


### Implementation Notes

Here is how the code is implemented to faster come to a conclusion how to write a test for

- Commands use `ExConstructor` for construction: `<Command>.new(attrs)`
- Errors from `Sportipedia.Catalog.dispatch` go through the `Validate` middleware which merges Vex errors into `%{field: [message]}`
- Vex presence validator message: `"must be present"`
- Ecto `unique_constraint` message from DB: `"has already been taken"`
- Ecto.Multi error tuples: `{:error, :multi_name, changeset, effects}`
