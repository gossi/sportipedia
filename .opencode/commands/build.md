---
name: build
description: Build domain features, or orchestrate multi-step work using recipes and specialized agents.
agent: builder
---

# Build

Orchestrate the work described by: $1

## Structured Call

If `$1` contains two parts (e.g. "domain-feature position"):

- First part: recipe name
- Second part: feature/operation/argument

Load `@recipes/<recipe>.recipe.md` and follow its steps.

## Single Parameter (NLU Fallback)

If `$1` is a single description (e.g. "create a new sport in the catalog"):

- Classify the intent
- Extract the operation and recipe
- If uncertain, ask me

## Available Recipes

- `build-spec` — Build everything in a spec document. You extract the operations
  yourself, group them into one slice per aggregate, build the slices **in
  parallel**, converge the shared registrations, and commit per feature.
- `domain-feature` — Build a complete feature slice: every operation of one
  aggregate, domain and web actors, in one plan / one implementer / one review.
  **Default choice.**
- `domain-operation` — Build only the domain actor of one operation. Standalone
  entry point for a single operation or a repair.
- `domain-endpoint` — Build only the web actor of one operation. Standalone entry
  point for a single endpoint or a repair.
- `domain-modelling` — Interactive domain model design (no swarm)
- Agent-only (no recipe) — Use the `reviewer` agent for post-implementation review

`domain-feature` does not compose the other two anymore — it inlines their work so
the shared scaffold is loaded once. The granular recipes stay at your disposal for
surgical work.

## What Is Yours vs Theirs

- **You**: extracting operations, preflight, gate commands, convergence
  regeneration, and every commit. Deterministic mechanics.
- **Subagents**: judgement — planning decisions, implementation, review. They never
  run git; they end with a `FILES:` list you commit.

Never `git add -A` while slices are in flight. Generators are append-only and
idempotent, so re-running them is the repair path for lost registrations — do not
hand-merge `router.ex`, `application.ex` or `supervisor.ex`.
