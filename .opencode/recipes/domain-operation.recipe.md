---
$schema: ./recipe.schema.yaml
name: domain-operation
description: Design, generate, implement, review and commit the domain actor of exactly one operation
parameters:
  operation:
    type: string
    required: true
    description: "The exact domain operation name (command or query)"
  spec_path:
    type: string
    required: false
    description: "Path to the governing spec, when one exists"
steps:
  - id: design
    agent: software-architect
    skill: plan-domain-feature
    with:
      scope: operation
      operation: "${parameters.operation}"
      spec_path: "${parameters.spec_path}"

  - id: generate
    agent: backend-engineer
    skill: use-blueprints
    with:
      phase: generate
      scope: domain
      operation: "${parameters.operation}"
      design: ${steps.design.result}

  - id: implement
    agent: backend-engineer
    skills:
      - tdd
      - use-blueprints
    with:
      phase: implement
      scope: domain
      operation: "${parameters.operation}"
      design: ${steps.design.result}
      generated_files: ${steps.generate.result}
      spec_path: "${parameters.spec_path}"

  - id: review
    agent: software-architect
    with:
      scope: operation
      operation: "${parameters.operation}"
      design: ${steps.design.result}
      files: ${steps.implement.result.files}

  - id: adjust
    agent: backend-engineer
    skills:
      - tdd
      - use-blueprints
    with:
      phase: adjust
      scope: domain
      operation: "${parameters.operation}"
      review: ${steps.review.result}
      design: ${steps.design.result}
      generated_files: ${steps.generate.result}
      files: ${steps.implement.result.files}
approval: auto
---

# Domain Operation Recipe

Design, generate, implement, review and commit exactly ONE CQRS/ES domain
operation.

Standalone entry point for a single operation or a repair. `domain-feature` does
not compose this recipe — it runs the same five phases across a whole aggregate in
one design — but this stays at your disposal, and it follows the same rules.

## Structure

| Step | Agent | Does |
|---|---|---|
| `design` | software-architect | lints the model, preflights spec against model, translates to technical design, emits the generator call sequence, the work package, the deviation register, the boundary |
| `generate` | backend-engineer | runs the calls verbatim, writes no logic, reports files touched |
| `implement` | backend-engineer | fills the residual bodies, writes the tests, test-first |
| `review` | software-architect | reviews the operation against the architecture |
| `adjust` | backend-engineer | applies findings, repairs via `--check`, commits |

## Rules

Inherited verbatim from [domain-feature](./domain-feature.recipe.md) — read its
prose sections rather than a copy of them here. Applies equally at this scope:
generators own layout and the design never names a file path; the generator runs
before logic and workers never run generators; generators append and never remove,
so a model deletion needs a hand-deletion pass; `--check` is classified from its
output and against the deviation register, never from its exit code; empty output
is not a pass; the design step asserts nothing about shared-infrastructure
behaviour without a citation or `UNVERIFIED`; the implementer is the only git
writer and commits the union of the generate report and its own `FILES:`.

## Scope boundary

Domain actor only. No controller, view, schema, web route, endpoint test or Bruno
file — that is `domain-endpoint`.

## What Gets Built

Public API function, command or query module, command handler, events, aggregate,
projector, read model, policy, validators and queries, internal API, migration,
all tests.

## When to Prefer domain-feature

For a fresh aggregate: it loads the shared scaffold once and reviews the whole
constituent, which is where cross-operation contamination is visible. Use this
recipe when exactly one operation of an existing aggregate needs work.
