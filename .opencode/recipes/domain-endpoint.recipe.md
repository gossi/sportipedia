---
$schema: ./recipe.schema.yaml
name: domain-endpoint
description: Design, generate, implement, review and commit the web endpoint of exactly one operation
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
      scope: endpoint
      operation: "${parameters.operation}"
      spec_path: "${parameters.spec_path}"

  - id: generate
    agent: backend-engineer
    skill: use-blueprints
    with:
      phase: generate
      scope: web
      operation: "${parameters.operation}"
      design: ${steps.design.result}

  - id: implement
    agent: backend-engineer
    skills:
      - tdd
      - use-blueprints
    with:
      phase: implement
      scope: web
      operation: "${parameters.operation}"
      design: ${steps.design.result}
      generated_files: ${steps.generate.result}
      spec_path: "${parameters.spec_path}"

  - id: review
    agent: software-architect
    with:
      scope: endpoint
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
      scope: web
      operation: "${parameters.operation}"
      review: ${steps.review.result}
      design: ${steps.design.result}
      generated_files: ${steps.generate.result}
      files: ${steps.implement.result.files}
approval: auto
---

# Domain Endpoint Recipe

Design, generate, implement, review and commit the web endpoint for exactly ONE
domain operation.

Standalone entry point for a single endpoint or a repair. `domain-feature` does
not compose this recipe — it builds domain and web actors in one design and one
implementation pass — but this stays at your disposal, and it follows the same
rules.

## Structure

| Step | Agent | Does |
|---|---|---|
| `design` | software-architect | preflights, translates the operation into endpoint design, emits the generator call sequence, the work package, the deviation register, the boundary |
| `generate` | backend-engineer | runs the calls verbatim — view, schemas, controller with route, Bruno — reports files touched |
| `implement` | backend-engineer | fills the residual bodies and the endpoint tests, test-first |
| `review` | software-architect | reviews the endpoint against the architecture |
| `adjust` | backend-engineer | applies findings, repairs via `--check`, commits |

## Rules

Inherited verbatim from [domain-feature](./domain-feature.recipe.md) — read its
prose sections rather than a copy of them here. Same applies at this scope: layout
belongs to the generators; generation precedes logic; workers never run
generators; generators append and never remove; `--check` is classified from its
output against the deviation register and never from its exit code; nothing about
shared-infrastructure behaviour is asserted without a citation or `UNVERIFIED`;
the implementer is the only git writer.

## Preconditions

The domain operation must already exist and be green. The endpoint wraps its
public API and nothing else — the controller calls exactly one function on the
constituent's port, and never touches `Repo`, queries, the aggregate or the
command struct.

## What the design must state for an endpoint

- **Authorization** — `Bodyguard.Plug.Authorize` on the controller with the
  constituent's policy, per ADR-0001, and the actor set from the ESDM.
- **Statuses** — which success status, and which error atom renders to which
  status through which component, each cited or marked `UNVERIFIED`.
- **The route** — full path and verb. Commands are POST; there is no PATCH, PUT or
  DELETE for a command.
- **Published contract** — request and response schemas, and the sort, filter and
  sparse-fieldset surfaces for a collection read.

## What Gets Built

Phoenix controller with `OpenApiSpex.ControllerSpecs`, router entry, JSON:API view,
OpenAPI request and response schemas, Bruno API documentation, all endpoint tests.
