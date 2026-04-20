# AGENTS.md - Agentic Coding Guidelines for Sportipedia

Guidelines for agentic coding agents operating in the Sportipedia repository.

> - **See [ARCHITECTURE.md](./ARCHITECTURE.md)** for detailed architecture documentation (C4 Model, DDD, CQRS/ES, directory structures).
> - **See [CODING-GUIDELINES.md](./CODING-GUIDELINES.md)** for code style guidelines, patterns, and conventions.

## Project Structure

Monorepo with pnpm workspaces:

- **Apps**: `apps/catalog`, `apps/admin` - Ember applications
- **Support**: `support/user`, `support/ui` - Ember addons
- **Services**:
  - `services/auth` - better-auth (Node.js backend w/ Hono)
  - `services/api` - Phoenix/Elixir API with Commanded for CQRS/ES
- **Packages**: `packages/ember-intl` - Internal packages

## Build, Lint, and Test Commands

### Root Level

```bash
pnpm clean           # Clean all dist folders
pnpm lint:css        # Stylelint
pnpm lint:hbs        # Ember template lint
pnpm lint:js         # ESLint
pnpm lint:types      # TypeScript checking
```

### Running Tests

```bash
cd apps/catalog && pnpm test           # Ember apps
cd services/api && mix test            # Phoenix/Elixir
```

### Phoenix/Elixir Commands

```bash
cd services/api
mix deps.get           # Install dependencies
mix ecto.setup        # Create DB, EventStore, migrate, seeds
mix ecto.reset        # Drop and re-setup DB
mix phx.server        # Start development server
mix test              # Run tests
mix phx.routes        # Show all routes
```

## Notes for Agents

- Always use `pnpm` (not `npm` or `yarn`) for Node.js
- Use TypeScript in `.ts` and `.gts` files
- Follow Ember Octane patterns (classic Ember patterns deprecated)
- Use `@ember/service` for services
- Use Glimmer components for new components
- Run `pnpm lint:types` before committing (Node.js)
- Run `mix format` before committing (Elixir)
- Elixir: Vex for validation, ExConstructor for struct creation
- See [ARCHITECTURE.md](./ARCHITECTURE.md) for directory structure and domain organization
- See [CODING-GUIDELINES.md](./CODING-GUIDELINES.md) for code style guidelines and patterns

## References to use Third-Party Libraries

- [better-auth](https://canary.warp-drive.io/llms.txt)

Backend:

- [commanded](https://hexdocs.pm/eventsourcingdb)
- [phoenix](https://hexdocs.pm/phoenix)
