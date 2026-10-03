# AGENTS.md - Agentic Coding Guidelines for Sportipedia

Sportipedia is a System helping you with your technical training in Sports.
Consisting of multiple subdomains to fulfill this mission.

- See [Domain Model](./docs/domain-model/README.md) - Explains the language this project speaks
- See [Architecture](./ARCHITECTURE.md) for detailed architecture documentation (C4 Model, DDD, CQRS/ES, directory structures).
- See [Coding Guidelines](./docs/coding-guidelines/README.md) for code style guidelines, patterns, and conventions.
- Understand the used [frameworks and libraries](../../docs/references/third-party-libraries.md)
- See [Code Access Policy](./.opencode/code-access-policy.md) for how to access code.

## Playwright MCP & Storybook

- Start Storybook: `pnpm exec storybook dev --no-open` (background it, log to a file inside the repo). The port is dynamic — read the "Local:" line from the log.
- Don't pass `--port` (fails) or `--quiet` (suppresses the URL output).
- Browser is headless (`chrome-for-testing`)
- Always shut down Storybook and the Playwright browser when done.
