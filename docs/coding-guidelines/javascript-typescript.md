# JavaScript/TypeScript Coding Guidelines

- **Package Manager**: pnpm (strict)

## General Guidelines

- Follow established lint rules from `eslint.config.js`
- Follow typescript rules from `tsconfig.json`

## Import Conventions

- Prefer absolute imports
- Relative imports only in places that have a public API as entry point (refer
  to [Architecture](../../ARCHITECTURE.md))
- Virtual path imports (use `#` prefix), refer to `package.json`

## File Naming

- Use kebap-case for file names, eg. `user-menu.gts`, `auth.ts`

## Linting + Formatting

Formatting runs through linting right now

- Use `lint:*` scripts from `package.json`
- Inspect `eslint.config.js` for rules
