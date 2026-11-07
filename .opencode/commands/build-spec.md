---
name: build-spec
description: Build a given spec — one spec is one aggregate, so it is one feature slice
agent: builder
---

# Build Spec: $1

Load the [spec recipe](@recipes/spec.recipe.md) and execute it.

Parameters:

- `${parameters.spec_path}` = `$1`

## What Runs

The recipe delegates once to `domain-feature`, which runs five phases: design
(software-architect), generate (backend-engineer), implement (one
backend-engineer per operation, in parallel), review (software-architect), adjust
and commit (backend-engineer).

The design step lints the domain model and preflights the spec against it before
anything is generated, and stops with `MODEL GAP:` where they disagree. That is
the earliest and cheapest place a model defect can be caught.

Report the slice outcome when it returns: operations built, review status, commit.
