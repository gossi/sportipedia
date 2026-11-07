---
name: build-domain-feature
description: Build a complete feature slice — every operation of one aggregate, design through commit
agent: builder
---

# Build Domain Feature: $1

Load the [domain-feature recipe](@recipes/domain-feature.recipe.md) and execute it.

Parameters:

- `${parameters.spec_path}` = `$1` — the governing spec

## Identity

Do not resolve the aggregate yourself. The design step lints the domain model,
reads the spec, groups every listed operation by `scope.aggregate` (queries by
`readModel`), and returns the identity with the operation list. Pass `aggregate`
and `composite` as overrides only if the user names them explicitly.

## Notes

- One agent call each for design, generate, review and adjust; one parallel worker
  per operation.
- Generation precedes all logic, so the shared scaffold exists before workers
  start. Workers never run generators.
- The implement workers share files first-come-first-served; the adjust step
  detects and repairs lost registrations, then commits.
- Give every delegation the **paths** — spec, domain model — not the pasted
  contents.
