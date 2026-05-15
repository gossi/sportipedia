---
status: draft
date: 2026-04-29
decision-makers: [thomas]
consulted: []
informed: []
---

# Authorization at Controller Level

## Context and Problem Statement

Sportipedia uses a CQRS/ES (Command Query Responsibility Segregation / Event Sourcing) architecture with bounded contexts. The system employs Guardian for authentication and Bodyguard for authorization.

Should authorization be at commands level, bounded context API or controller
level? In the future the authorization layer should be replaceable with a ReBAC
based system (see [project zanzibar](https://research.google/pubs/zanzibar-googles-consistent-global-authorization-system/))

## Decision Drivers

1. **Architectural purity** - Hexagonal architecture suggests authorization at the domain boundary (API layer)
2. **Testability** - Commands without auth are easier to unit test
3. **Single entry point** - Currently, controllers are the only planned entry to the domain
4. **Framework capabilities** - Phoenix controllers and Bodyguard's `Bodyguard.Plug.Authorize` provide plug-based authorization
5. **Exchangeability** - From policy based system to ReBAC system

## Considered Options

### Option 1: Move Authorization to Bounded Context API Layer

Move `@behaviour Bodyguard.Policy` and `authorize/3` callbacks to API modules (e.g., `InstrumentApi`).

- **Pros**:
  - Follows hexagonal architecture strictly
  - Authorization at true domain boundary
  - API layer explicitly defines access control
  
- **Cons**:
  - Very unergonomic programming, very repetitive
  - Hardcoded the authorization layer into the API function call
  - Requires wrapper functions to hide explicit `Bodyguard.permit?/4` calls
  - Additional abstraction layer (e.g., `authorize_and_run/4` wrappers)
  - No immediate benefit since controllers are the only entry point

### Option 2: Keep Authorization at Controller Level (Chosen)

Use Bodyguard's `Bodyguard.Plug.Authorize` in router pipelines or `Bodyguard.Plug.Guard` in controllers.

- **Pros**:
  - Simpler implementation with existing Phoenix/Bodyguard patterns
  - All auth information (user, params) already available at controller level
  - Clear, explicit authorization in router/controller where requests are handled
  - No additional wrapper abstractions needed
  - Aligns with current Guardian authentication pipeline (`:catalog`, `:admin`
    pipelines)
  - Exchangeability is somewhat given
  
- **Cons**:
  - Not at the "true" hexagonal boundary (API layer)
  - If new entry points emerge (e.g., background jobs, CLI), auth must be added there

## Decision Outcome

**Chosen option**: Option 2 - Keep Authorization at Controller Level

### Rationale

1. **Single entry point**: Currently, controllers are the only planned entrance to the domain. There are no other adapters or ports planned that would bypass controllers.

2. **Framework support**: Phoenix's router pipelines (`:catalog`, `:admin`) and Bodyguard's plug integration (`Bodyguard.Plug.Authorize`, `Bodyguard.Plug.Guard`) provide clean, declarative authorization at the controller level.

3. **Available context**: All necessary information (user from Guardian `conn.assigns[:guardian_user_resource]`, params, action) is available at the controller/router level where Bodyguard plugs operate.

4. **Simplicity**: Avoiding wrapper functions and additional abstraction layers reduces complexity without sacrificing security.

5. **Consistency**: The existing authentication already happens at the controller level via Guardian pipelines (`Sportipedia.Auth.Pipeline.Catalog`). Keeping authorization at the same level is coherent.

## Consequences

### Good

- **Simplicity**: Authorization logic is where the request is handled, easy to understand
- **Testability**: Commands can be unit tested without mocking users or auth contexts
- **Consistency**: Auth and authorization co-located at controller level
- **Performance**: No additional abstraction layers or wrapper function overhead

### Bad

- **Architectural impurity**: Not at the "true" hexagonal boundary (if strict adherence is required)
- **Future risk**: If new entry points (background jobs, CLI, internal services) are added, authorization must be explicitly added there
- **Domain coupling**: Commands are not self-protecting; they rely on external
  auth enforcement (missing arch lint. Commands shall never dispatched manually,
  only through bounded context API)

### Neutral

- **Current architecture fit**: Aligns with Phoenix conventions and Guardian's controller-level authentication
- **Team familiarity**: Uses patterns the team already knows (plugs, pipelines)

## Definition of Done Checklist

- [x] **E**xplicit problem statement (Context section defines the authorization placement question)
- [x] **C**omprehensive options analysis (2 options with pros/cons analyzed)
- [x] **A**ctionable decision (Option 2 chosen with clear rationale)
- [x] **D**ocumented consequences (Good/Bad/Neutral sections completed)
- [x] **R**eviewable by stakeholders (Clear structure, YAML frontmatter with decision-makers)

## Notes

- If new entry points to the domain are planned (e.g., background workers, CLI tools), reconsider moving authorization to the API layer (Option 1)
- The current approach is acceptable given the single entry point constraint
- This decision should be revisited if the architecture evolves to include multiple adapters
