---
name: build
description: Build domain features, or orchestrate multi-step work using recipes and specialized agents.
agent: builder
model: opencode-go/deepseek-v4-flash
---

# Build

Orchestrate the work described by: $1

## Structured Call

If `$1` contains two parts (e.g. "domain-feature CreateSport"):

- First part: recipe name
- Second part: operation/argument

Load `@recipes/<recipe>.recipe.md` and follow its steps.

## Single Parameter (NLU Fallback)

If `$1` is a single description (e.g. "create a new sport in the catalog"):

- Classify the intent
- Extract the operation and recipe
- If uncertain, ask me

## Available Recipes

- `build-spec` — Build everything described in a spec document (parses spec, iterates over all operations, commits after each)
- `domain-feature` — Build a domain operation + its web endpoint
- `domain-operation` — Build only the domain operation
- `domain-endpoint` — Build only the web endpoint
- `domain-modelling` — Interactive domain model design (no swarm)
- Agent-only (no recipe) — Use the `reviewer` agent for post-implementation review
