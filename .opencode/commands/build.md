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
- Second part: spec path / operation name

Load `@recipes/<recipe>.recipe.md` and follow its steps.

## Single Parameter (NLU Fallback)

If `$1` is a single description (e.g. "create a new sport in the catalog"):

- Classify the intent
- Extract the operation and recipe
- If uncertain, ask me

## Available Recipes

- `build-spec` — Build everything in a spec document. One spec is one aggregate,
  so this is one feature slice.
- `domain-feature` — Build a complete slice: every operation of one aggregate,
  domain and web actors. **Default choice.** Design → generate → implement (one
  parallel worker per operation) → review → adjust and commit.
- `domain-operation` — Build only the domain actor of one operation. Standalone
  entry point for a single operation or a repair.
- `domain-endpoint` — Build only the web actor of one operation. Standalone entry
  point for a single endpoint or a repair.
- `domain-modelling` — Interactive domain model design (no swarm)

`domain-feature` does not compose the other two — it runs the same five phases in
one design across the whole aggregate. The granular recipes stay at your disposal
for surgical work.

## Subagents

| Agent | Role |
|---|---|
| `software-architect` | Design and review. Never edits a file |
| `backend-engineer` | Generates, implements, and commits |
| `product-specialist` | Owns the spec and the ESDM domain model |

## What Is Yours vs Theirs

You delegate and relay. Every action — linting, generating, implementing,
reviewing, committing — belongs to a subagent. You never run a command, never
read an implementation file, and never touch git.

When relaying, pass artifacts by path and forward structured results verbatim. A
paraphrase of a finding becomes an instruction in the next agent's hands, and an
incorrect instruction propagates further than the original error.
