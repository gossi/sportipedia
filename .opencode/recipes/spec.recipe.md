---
$schema: ./recipe.schema.yaml
name: spec
description: Build everything described in a spec document — one spec is one aggregate, so it is one feature slice
parameters:
  spec_path:
    type: string
    required: true
    description: "Path to the spec markdown file (e.g., docs/specs/catalog/athlete/spec-position-05-11-2026.md)"
steps:
  - id: build
    recipe: domain-feature
    with:
      spec_path: "${parameters.spec_path}"
approval: auto
---

# Build Spec Recipe

Build the complete contents of a spec document.

## Structure

A spec describes **one aggregate**. Its `## Domain Model` section lists the
commands, queries, events and read model of a single constituent, so the whole
document is one feature slice and the recipe is a single delegation to
`domain-feature`.

There is no fan-out here, and no per-aggregate loop. Parallelism lives inside the
slice — one backend-engineer per operation, concurrent — not between aggregates,
because a spec has only one.

## Resolution

`domain-feature` resolves its own identity: the design step lints the model, reads
the spec, and groups every listed operation by `scope.aggregate` (queries by
`readModel`), so the aggregate name is derived rather than assumed from the spec's
frontmatter. Pass `aggregate` and `composite` explicitly only to override that.

## Precondition

The ESDM domain model files referenced in the spec's `## Domain Model` section must
already exist and be populated. Domain modelling is complete before this recipe
runs. The design step verifies it with `esdm lint` (is the model well-formed?) and
`mix sp.check` (does it carry everything the generators need — fixture contract,
prose slots), and raises `MODEL GAP:` where the model and the spec disagree; that
is a stop, not a warning.

## Reporting

When the slice returns, report to the user:

```
Build complete for {spec_path}
  aggregate   {name} — {n} operations
  design      {operations} · {deviations registered} · {MODEL GAPs raised}
  review      {pass | warn | fail}
  commit      {hash}
```

On `fail`, report which work package it came from and what `must_change` is still
open — do not retry the whole slice.
