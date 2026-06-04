---
status: draft
date: 2026-06-02
decision-makers: [thomas]
consulted: []
informed: []
---

# Use Builder Agent with Recipe-Driven Orchestration

## Context and Problem Statement

Sportipedia uses opencode as its agentic coding environment. Originally there was a single `domain-driven-developer` agent handling all tasks: domain modelling, planning, implementation, and testing. As the project grows, this monolithic agent approach has several problems:

1. **No specialization** — The same agent context must cover strategic domain design and tactical Elixir implementation, forcing compromises in system prompts.
2. **No orchestration** — There is no mechanism to chain multiple skills or sub-tasks (e.g., plan → implement → review) without manual re-prompting.
3. **No reuse** — Workflows like "find the operation, plan it, implement it with TDD, build the endpoint" have to be re-described every time.
4. **No review** — Implementation happens without automated verification against architecture guidelines.

How should we structure agents, commands, and skills to enable multi-step, multi-agent workflows with reusable workflow definitions?

## Decision Drivers

- **Separation of Concerns** — Different cognitive work (design, planning, implementation, review) should have dedicated agents with tailored constraints.
- **Minimize Cognitive Load** — Workflows should be codified as reusable recipes, not re-described each time.
- **Composability** — Recipes must compose (a domain feature recipe includes an operation recipe and an endpoint recipe) and support iteration (a spec recipe loops over multiple operations).
- **Backward Compatibility** — Existing commands (`/build-domain-feature`, `/domain-modelling`) should continue to work.
- **Convenience** — Direct shortcuts for common tasks should exist alongside the general orchestrator.
- **Keep It Simple** — Use opencode's native primitives (agents, commands, skills, task tool) without building a workflow engine.

## Considered Options

- **Option 1: Monolithic agent with directive commands** — Keep a single primary agent; use commands only as instruction files that tell the agent what to do. No subagents, no orchestration.
- **Option 2: Builder agent as orchestrator with subagents** — Introduce a builder agent that decomposes tasks and delegates to specialized subagents (planner, implementer, reviewer). Workflows defined as structured recipe files with YAML frontmatter.
- **Option 3: Pipeline via shell scripts** — Define workflows as shell scripts that invoke opencode CLI commands sequentially. No agent orchestration.

## Decision Outcome

Chosen option: **Option 2 — Builder agent with recipe-driven orchestration**, because it provides clear separation of concerns, composable workflow definitions, and leverages opencode's native subagent (`task` tool) and skill mechanisms without introducing external dependencies.

### Consequences

- Good, because each agent has a focused responsibility with tailored constraints (e.g., the planner never writes code; the implementer never redesigns).
- Good, because recipes codify workflows as structured files that both the builder (orchestrator) and direct commands can reference — no workflow knowledge is duplicated.
- Good, because the recipe format supports composition (`recipe:` steps), iteration (`for-each:`), and parameter passing (`${...}` expressions), enabling future spec-driven builds.
- Good, because the `domain-modelling` command stays on the `domain-designer` agent (unchanged), preserving the interactive modelling workflow.
- Bad, because the builder introduces indirection — a simple operation build goes through three subagent delegations instead of one direct agent session.
- Bad, because subagent delegation via `task` tool may be slower than direct agent execution (multiple LLM invocations).
- Neutral, because the existing build command shortcuts (`/build-domain-feature`, etc.) are preserved as thin wrappers that invoke the same recipes through the builder, maintaining auto-complete convenience.

### Confirmation

- The file system layout under `.opencode/agents/`, `.opencode/recipes/`, and `.opencode/commands/` reflects the design.
- The builder agent's system prompt defines subagent routing rules and recipe loading behavior.
- Direct commands invoke the builder with a recipe reference; `domain-modelling` invokes `domain-designer` directly.

## Pros and Cons of the Options

### Option 1: Monolithic agent with directive commands

- Good, because simplest setup — a single agent with a few command files.
- Good, because no subagent overhead or latency from delegation.
- Bad, because the agent context becomes cluttered with concerns from all domains (DDD, Elixir, security).
- Bad, because there is no mechanism to chain steps or reuse workflows.
- Bad, because no automated review step exists.
- Bad, because scaling to future roles (frontend engineer, security reviewer) means growing the same agent prompt.

### Option 2: Builder agent with recipe-driven orchestration

- Good, because each agent has a clean, single responsibility.
- Good, because recipes are reusable, composable, and parameterizable.
- Good, because the same recipes power both the orchestrator and direct commands.
- Good, because the recipe format (YAML frontmatter + markdown body) is both machine-parseable and human-readable.
- Bad, because subagent delegation adds latency compared to direct execution.
- Bad, because recipe interpretation depends on the LLM correctly parsing frontmatter and following steps.
- [INVESTIGATE: Measure actual overhead of subagent delegation vs. direct agent execution for a typical domain feature build.]

### Option 3: Pipeline via shell scripts

- Good, because shell scripts are familiar and deterministic.
- Good, because pipeline steps can be parallelized independently.
- Bad, because opencode command-line invocations from scripts lose interactive context and agent state.
- Bad, because shell scripts cannot load skills or leverage agent expertise mid-pipeline.
- Bad, because error handling and user interaction (approval gates) are harder to implement in scripts.

## More Information

### Agent Architecture

```
┌──────────────────────────────────────────────────────────┐
│  /build <task>        /build-domain-feature <op>         │
│  Command (builder)    Command (builder, recipe shortcut) │
└───────────────────────┬──────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────┐
│  Builder (primary agent, cheap model)                    │
│  - Classifies task / loads recipe                        │
│  - Routes steps to subagents via task tool               │
│  - Handles approval gates (auto/manual)                  │
│  - Summarizes results                                    │
└────┬──────────┬────────────┬────────────────┬────────────┘
     │          │            │                │
     ▼          ▼            ▼                ▼
┌────────┐ ┌────────┐ ┌───────────┐ ┌──────────┐
│Software│ │Backend │ │ Reviewer  │ │ Domain   │
│Architect││Engineer│ │(subagent) │ │ Designer │
│(subagent)│(subagent)│           │ │(primary) │
│Planner  │ │Implement│ │Review    │ │Model     │
└────────┘ └────────┘ └───────────┘ └──────────┘
```

### File Layout

```
.opencode/
├── agents/
│   ├── builder.md               (mode: primary,   model: cheap)
│   ├── domain-designer.md       (mode: primary,   model: default)
│   ├── backend-engineer.md      (mode: subagent,  model: qwen)
│   ├── software-architect.md    (mode: subagent,  model: qwen)
│   └── reviewer.md              (mode: subagent,  model: cheap)
├── recipes/
│   ├── domain-feature.recipe.md
│   ├── domain-operation.recipe.md
│   └── domain-endpoint.recipe.md
└── commands/
    ├── build.md                              # entry point
    ├── build-domain-feature.md               # → builder + domain-feature recipe
    ├── build-domain-operation.md             # → builder + domain-operation recipe
    ├── build-domain-endpoint.md              # → builder + domain-endpoint recipe
    └── domain-modelling.md                   # → domain-designer (unchanged)
```

### Recipe Format

Recipes use YAML frontmatter with a `steps` array and markdown body for human-readable explanation.

```yaml
---
name: domain-feature
description: Build operation + endpoint
parameters:
  operation: { type: string, required: true }
steps:
  - id: find
    agent: software-architect
    skill: find-domain-operation
    with: { operation: ${parameters.operation} }

  - id: build-operation
    recipe: domain-operation
    with: { operation: ${parameters.operation} }

  - id: build-endpoint
    recipe: domain-endpoint
    with: { operation: ${parameters.operation} }

  - id: review-loop
    loop:
      max: 3
      steps:
        - agent: reviewer
          exit-when: ${result.review.status} == "pass"
        - agent: backend-engineer
          skills:
            - tdd
            - seek-implementation-for-domain-operation
            - seek-implementation-for-domain-operation-test
          with: { operation: ${parameters.operation} }
approval: auto
---
```

Step primitives:
- `skill: <name>` + `agent:` — Load a single skill via the `skill` tool and delegate to the named subagent.
- `skills: [<name>, ...]` + `agent:` — Load multiple skills and delegate to the named subagent to combine and execute them.
- `agent:` only — Delegate directly to the subagent without loading any skill. The subagent's system prompt is sufficient (used for review).
- `recipe: <name>` — Load and execute a sub-recipe recursively.
- `loop:` — Repeated execution of child steps. Two modes:
  - **Iteration** (`over:`): Loop over a list, executing child steps once per item. `${item}` is available in step bindings.
  - **Conditional** (`max:` + `exit-when` on a child step): Repeat child steps until a step's `exit-when` condition is met, or `max` iterations are reached. Prevents infinite loops.
- `with: { key: value }` — Parameter bindings using `${...}` expressions (`${parameters.<name>}`, `${steps.<id>.result}`, `${item}`).

### Subagent Delegation

Each recipe step explicitly declares which agent handles it via the `agent:` field.
The builder reads this field and delegates to the named subagent using the `task` tool.
This keeps routing knowledge in the recipe, not in the builder's system prompt.

For `agent:`-only steps (no skill), the builder passes operational context
(operation name, previous results) in the task prompt. The subagent's system
prompt contains all instructions needed — no skill loading required.

### Loop Patterns

Two loop patterns emerged from the requirements:

**1. Spec-driven iteration (`over:`):** A future `build-spec` recipe will parse a
spec document into a list of operations and iterate over them, building each one.
`${item}` references the current element.

**2. Review feedback loop (`exit-when:`):** After initial implementation, a
review loop cycles between the reviewer agent and the backend engineer. The
reviewer checks the implementation; if it finds warnings or errors, the backend
engineer fixes them. The loop exits when the reviewer gives a passing verdict,
or when `max` iterations are reached (safety limit).

### Recipe Schema

A JSON Schema at `.opencode/recipes/recipe.schema.json` validates recipe files.
It defines the full grammar: `name`, `description`, `parameters`, `steps`,
`approval`, and the various step types including `loop`. Recipe files can
reference it via `$schema` for editor validation.

### Approval Gates

- `approval: auto` — Execute all steps without user interruption.
- `approval: manual` — Present the plan to the user after planning steps; ask for approval before proceeding.
- Fallback: If the builder cannot classify a task or no planning skill exists for a step, it asks the user for guidance.

### Renaming History

The original `domain-driven-developer` agent was:

1. **Renamed** to `domain-designer` (primary agent) — continues to serve the `domain-modelling` command.
2. **Duplicated** and adapted to `backend-engineer` (subagent mode) — serves implementation delegation with identical docs-first, code-access-policy constraints.
