# Backend Coding Guidelines

> **See [ARCHITECTURE.md](../ARCHITECTURE.md)** for detailed architecture documentation (C4 Model, DDD, CQRS/ES, directory structures).

## Frameworks & Languages

- **Phoenix**: Elixir ~1.18, follow Elixir conventions
- **Node.js**: TypeScript primarily (better-auth service with Hono)
- **Package Manager**: mix for Elixir

## Import Conventions

### Node.js

```typescript
import { Hono } from 'hono';
import { betterAuth } from 'better-auth';
```

## File Naming

| File Type | Convention | Example |
|-----------|------------|---------|
| Elixir | `*.ex`, `*.exs` | `user.ex`, `user_controller.ex` |
| Commands | `*_command.ex` | `register_user.ex` |
| Events | `*_event.ex` | `user_registered.ex` |
| Aggregates | `*_aggregate.ex` | `user.ex` |
| Handlers | `*_handler.ex` | `register_user_handler.ex` |
| Tests | `*_test.exs` | `user_test.exs` |

## Elixir/Phoenix Patterns

### Module Structure

```elixir
defmodule Sportipedia.Accounts.Commands.RegisterUser do
  # ...
end
```

### Aggregate (Event Sourcing)

```elixir
defmodule Sportipedia.Accounts.Aggregates.User do
  defstruct [:id, :username, :email, :hashed_password, :profile]

  alias Sportipedia.Accounts.Events.UserRegistered

  def apply(%User{} = user, %UserRegistered{} = registered) do
    %User{user | id: registered.id}
  end
end
```

### Command Handler

```elixir
defmodule Sportipedia.Accounts.CommandHandlers.RegisterUserHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Accounts.Commands.RegisterUser
  alias Sportipedia.Accounts.Events.UserRegistered

  def handle(aggregate, %RegisterUser{} = cmd) do
    with {:ok, user} <- create_user(cmd) do
      %UserRegistered{id: user.id}
    end
  end
end
```

### Validation

Use `Vex.Struct` for validation, `ExConstructor` for struct creation.

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

## Linting

- **Elixir**: mix format (run before committing)

## Important Patterns

1. **CQRS/ES**: Commands → Events → Aggregates → Projections

## Notes

- Run `mix format` before committing (Elixir)
