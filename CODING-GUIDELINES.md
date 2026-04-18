# CODING.md - Code Style Guidelines

This document covers code style, patterns, and conventions for the Sportipedia codebase.

> **See [ARCHITECTURE.md](./ARCHITECTURE.md)** for detailed architecture documentation (C4 Model, DDD, CQRS/ES, directory structures).

## General Principles

### Frameworks & Languages

- **Ember**: Ember Octane (modern Ember with Glimmer)
- **Node.js**: TypeScript primarily, with .gts for templates
- **Phoenix**: Elixir ~1.18, follow Elixir conventions
- **Package Manager**: pnpm (strict), mix for Elixir
- **Node Version**: >= 24

### Import Conventions

#### Ember

Virtual path imports (use `#` prefix) for app-local modules:

```typescript
import UserMenu from '#/components/user-menu.gts';
import { auth } from '#/auth';
import { t } from 'ember-intl';
import type { User } from '@sportipedia/user';
```

#### Node.js

Standard imports:

```typescript
import { Hono } from 'hono';
import { betterAuth } from 'better-auth';
```

## File Naming

| File Type | Convention | Example |
|-----------|------------|---------|
| TypeScript | `*.ts` | `auth.ts` |
| Glimmer TS | `*.gts` | `user-menu.gts` |
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

### Naming Conventions (Elixir)

| Type | Convention | Example |
|------|------------|---------|
| Modules | PascalCase | `Sportipedia.Accounts` |
| Functions | snake_case | `register_user` |
| Variables | snake_case | `user_data` |
| Atoms | snake_case | `:user`, `:admin` |
| Files | snake_case.ex | `user_controller.ex` |

## Ember Components

### Class Components (.gts)

```typescript
import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { service } from '@ember/service';

export default class MyComponent extends Component<Args> {
  @tracked data: SomeData | null = null;
  @service declare auth: AuthService;

  <template>
    <div>{{@title}}</div>
  </template>
}
```

### Template-Only Components (.gts)

```typescript
import type { TOC } from '@ember/component/template-only';

const MyComponent: TOC<{ Args: { title: string } }> = <template>
  <div>{{@title}}</div>
</template>;

export default MyComponent;
```

### State Management

- `@glimmer/tracking` with `@tracked` for reactive state
- `ember-resources` for async data:
  ```typescript
  import { resource } from 'ember-resources';
  const userResource = resource(async () => await fetchUser());
  ```
- `@warp-drive/core` Store for data/cache

## TypeScript Guidelines

- Explicit types for function arguments and return types
- Use `type` for aliases, interfaces for objects
- Import types separately
- Avoid `any`, use `unknown` when type is unknown

## Error Handling

### Frontend (Ember)

Use try/catch, display via `ApiError` component.

### Backend (Node.js)

```typescript
try {
  // operation
} catch (error) {
  return c.json({ error: 'Message' }, 500);
}
```

### Backend (Elixir)

```elixir
case Accounts.register_user(params) do
  {:ok, user} -> json(conn, %{user: user})
  {:error, :username_taken} -> put_status(conn, 422) |> json(%{error: "taken"})
end
```

## CSS and Styling

- **ember-scoped-css** for component-scoped styles
- **Stylelint** for CSS linting (follows stylelint-config-standard)

## Linting

- **Ember**: ESLint, Prettier, Stylelint, Template Lint
- **Elixir**: mix format (run before committing)

## Important Patterns

1. **Registry services**: `buildRegistry({ 'service:auth': AuthService })`
2. **Link navigation**: `import { link } from 'ember-link';`
3. **Page titles**: `import { pageTitle } from 'ember-page-title';`
4. **i18n**: `import { t } from 'ember-intl';`
5. **CQRS/ES**: Commands → Events → Aggregates → Projections

## Notes

- Use `pnpm` (not `npm` or `yarn`) for Node.js
- Follow Ember Octane patterns (classic Ember patterns deprecated)
- Use `@ember/service` for services
- Use Glimmer components for new components
- Run `pnpm lint:types` before committing (Node.js)
- Run `mix format` before committing (Elixir)