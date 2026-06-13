---
name: seek-implementation-for-domain-operation-test
description: Seek implementation details for a vertical-slice read or write CQRS/ES operation in the Sportipedia domain.
---

# Implement Domain Operation Test

## Overview

Gives implementation details for a test about exactly ONE! CQRS/ES operation in the Sportipedia domain.
The operation is defined in the [Domain Model](../../../docs/domain-model/README.md).

Context: This should be run when a plan for that operation is ready for implementation.

## When to Use This Skill

Use this skill when:

- You have a plan for implementing a domain operation
- The operation is known
- You are using TDD to implement
- You are about to write a test
- You are seeking a way to structure the test file
- You need to know what you want/need to test

## Context for Execting the Skill

- [Read Placeholder Naming Substitution](../../../docs/architecture/naming-substitution.md)
- [Respect Code Access Policy](../../code-access-policy.md) — **HARD CONSTRAINT**: Reading implementation code for patterns or reference is a task failure, not a warning. If violated: STOP, announce the violation, discard all knowledge from that code, and restart from documentation.
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

File Location: `/services/api/test/sportipedia/catalog/<_composite>/<domain_object>/operation/<_operation>_test.exs`

The test may (if applicable) cover the following:

- Policy
- Command
- Command Handler
- Event
- Event Handler
- Aggregate
- Projector
- Public API

Each is represented as a `describe` block in the test file and explained below.

### Policy

Tests `Policy.authorize/3` — pure function

### Command

- Struct creation with enforced fields
  - When testing enforced fields, use `struct!(Command, %{})` which raises
    `ArgumentError` if required fields are missing
  - Optional fields (no `enforce: true`) can be omitted in struct literals
    without raising — test this by creating events without optional fields
- Validation

### Handler

Tests the command handlers, input into output. Ideally pure, integration tests when needed.

### Event

Tests events.

- Struct creation with enforced fields
  - When testing enforced fields, use `struct!(Event, %{})` which raises
    `ArgumentError` if required fields are missing
  - Optional fields (no `enforce: true`) can be omitted in struct literals
    without raising — test this by creating events without optional fields
- Serialization, via `Jason.encode!(event)`

### Event Handler

tbd.

### Aggregate

Tests `Aggregate.apply/2` for the specific event.

```elixir
test "applies <-event> to aggregate state" do
  event = %<Event>{...}
  result = Aggregate.apply(%Aggregate{}, event)
  assert result.field == value
end
```

### Projector

Tests the projection logic by calling the projector's `handle/2` directly — needs DB.

The `project` macro in `projector.ex` generates a `handle(event, metadata)` function clause. 

- Call `handle/2` with the event and a metadata map (see template below)
  - Required fields: `handler_name`, `event_number`
  - The `handler_name` in test metadata MUST exactly match the `:name` option in the projector's `use Commanded.Projections.Ecto` declaration.
  - The `event_number` to be: unique non-negative integer

Example:

```elixir
metadata = %{
  handler_name: "<_projection>",
  event_number: 1,
  event_id: UUID.uuid4(),
  stream_id: "entity-#{event.id}",
  stream_version: 1,
  correlation_id: nil,
  causation_id: nil,
  created_at: DateTime.utc_now(),
  application: Sportipedia.<Subdomain>,
  state: nil
}
```

**Success case:**

```elixir
assert :ok = <Projector>.handle(event, metadata)

record = Repo.get!(ReadModel, event.id)
assert record.field == expected
```

**Idempotency case** (same `event_number` is skipped via `ProjectionVersion`):

```elixir
assert :ok = <Projector>.handle(event, metadata)
assert :ok = <Projector>.handle(event, metadata)

assert [record] = Repo.all(ReadModel)
```

**Error case** (e.g. DB constraint violation):

```elixir
assert {:error, _} = <Projector>.handle(event, metadata)
```

### Public API

Tests the public API — needs event store (InMemory) and DB and all relevant public API call.

- test success
- test validation (response is: `{:error, {:validation_failure, %{field: [message]}}}`)
- test failures

## Test Guidelines

Location: `test/sportipedia/catalog/<_composite>/<domain-object>/operation/<_operation>_test.exs`

### Test Module Pattern

Here is an example, take it as a template:

```elixir
defmodule Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test do
  use Sportipedia.<Subdomain>TestCase

  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Policy
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>Handler
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<Aggregate>
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<ReadModel>
  alias Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<Projector>
  alias Sportipedia.<Subdomain>.Repo
end
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
- Errors from `Sportipedia.<Subdomain>.dispatch` go through the `Validate` middleware which merges Vex errors into `%{field: [message]}`
- Vex `presence` validator message: `"must be present"`
- Ecto `unique_constraint` message from DB: `"has already been taken"`
- Ecto.Multi error tuples: `{:error, :multi_name, changeset, effects}`

## Verification — Before Declaring Done

Check each item. If any is "no", you have scope creep:

- [ ] Did I create files ONLY for the named operation?
- [ ] Did I read any implementation files? (should be: no)
- [ ] Did I follow directory structure from docs, not from existing code?
