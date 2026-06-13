# Elixir Coding Guidelines

## Elixir/Phoenix Patterns

- Module structure does not necessarily follow the directory structure

### Conventions and Guidelines

- Follow [Sportipedia Naming Conventions](./naming-conventions.md)

## Documentation

- Use `@moduledoc` and `@doc` for documenting source code
- Use `@spec` on functions

## Testing

### Running Tests

There is a couple of ways to run a portion of test.

- Entire Testsuite: `mix test` (use sparingly, only for regression)
- Directory: `mix test path/to/dir` (use to run a collection of test)
- File: `mix test path/to/file.exs` (use for TDD)
- Single test: `mix test path/to/file.exs:lineNumber` (use for TDD)

Run as minimal as possible and as much as needed. No need to run the entire test
suite, when one test is enough (saves time).

Plus the documentation for `mix test` contains other filter parameters.

### Covering Functionality

Apply both:

- Positive testing: verifies that the system works as expected with valid inputs.
- Negative testing: checks how the system handles invalid, unexpected, or edge-case inputs.

### Tagging Convention

Test tags determine which tests run and how they're categorised. Use the highest level that's correct for all tests in that scope, then narrow only when a subset differs.

#### Available Tags

| Tag            | Meaning                                                |
| -------------- | ------------------------------------------------------ |
| `:unit`        | Pure logic, no infrastructure dependency               |
| `:integration` | Needs `Catalog.Repo` DB, event store, or HTTP endpoint |

#### Tag Placement (highest to lowest)

**`@moduletag`** — applies to every test in the module. Use when ALL tests share the same tag.

```elixir
defmodule SportipediaWeb.Catalog.Equipment.InstrumentSchemaTest do
  use ExUnit.Case
  @moduletag :unit

  describe "InstrumentResponse" do
    test ... end
  end

  describe "InstrumentListResponse" do
    test ... end
  end
end
```

**`@describetag` inside `describe`** — applies to all tests within that describe block. Use when a group of tests share the same tag but the module has mixed tags.

```elixir
@tag :integration
describe "POST catalog-instrument" do
  test ... end
  test ... end
end
```

**`@tag` on individual `test`** — overrides any broader tag for that single test. Use sparingly.

#### Rule of thumb

Attach at the highest level that's correct for all tests in that scope. Only move to a lower organisational unit when a subset differs.

## Formatting

- `mix format` (run before committing)

## Important Patterns

1. **CQRS/ES**: Commands → Events → Aggregates → Projections
2. **UUID**: When dealing with ids, use the `UUID` module
    - Use `UUID.info(maybe_id)` for verifying a UUID
    - Use `UUID.uuid4()` for making a UUID
