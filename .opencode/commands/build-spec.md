---
name: build-spec
description: Build a given spec
agent: builder
---

# Build Spec: $1

Load the [spec recipe](@recipes/spec.recipe.md) and execute it.

Parameters:

- `${parameters.spec_path}` = `$1`

## What Runs

Three calls. `plan` runs the software-architect, which reports what the document
states and then the work it implies, split into generated work and manual work.
`implement` runs the software-engineer, which uses the generators for everything a
generator owns and writes the rest test-first, in whichever sides the spec's `scope`
declares. The review loop runs the software-architect against the spec and the
working tree, and the software-engineer applies findings when the review fails,
three iterations at most.

Report the outcome when it returns: what was planned, what was built, review status,
and what stays open. Nothing commits.
