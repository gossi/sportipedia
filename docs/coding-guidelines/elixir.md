# Elixir Coding Guidelines

## File Naming

| File Type | Convention | Example |
|-----------|------------|---------|
| Elixir | `*.ex`, `*.exs` | `user.ex`, `user_controller.ex` |
| Tests | `*_test.exs` | `user_test.exs` |

## Elixir/Phoenix Patterns

- Module structure does not necessarily follow the directory structure

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Modules | PascalCase | `Sportipedia.Accounts` |
| Functions | snake_case | `register_user` |
| Variables | snake_case | `user_data` |
| Atoms | snake_case | `:user`, `:admin` |
| Files | snake_case.ex | `user_controller.ex` |

## Error Handling

### Node.js

```typescript
try {
  // operation
} catch (error) {
  return c.json({ error: 'Message' }, 500);
}
```

### Elixir

```elixir
case Accounts.register_user(params) do
  {:ok, user} -> json(conn, %{user: user})
  {:error, :username_taken} -> put_status(conn, 422) |> json(%{error: "taken"})
end
```

## Testing

### Tagging Convention

Test tags determine which tests run and how they're categorised. Use the highest level that's correct for all tests in that scope, then narrow only when a subset differs.

#### Available Tags

| Tag | Meaning |
|-----|---------|
| `:unit` | Pure logic, no infrastructure dependency |
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

- **Elixir**: mix format (run before committing)

## Important Patterns

1. **CQRS/ES**: Commands → Events → Aggregates → Projections

## Notes

- Run `mix format` before committing (Elixir)
