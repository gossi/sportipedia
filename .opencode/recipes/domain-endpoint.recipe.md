---
$schema: ./recipe.schema.yaml
name: domain-endpoint
description: Plan and implement a web endpoint for a domain operation
parameters:
  operation: { type: string, required: true, description: "Domain operation name" }
steps:
  - id: plan
    agent: software-architect
    skill: plan-domain-endpoint
    with: { operation: ${parameters.operation} }

  - id: implement
    agent: backend-engineer
    skills:
      - tdd
      - seek-implementation-for-endpoint
      - seek-implementation-for-endpoint-test
    with: { operation: ${parameters.operation} }
approval: auto
---

# Domain Endpoint Recipe

Plan and implement the web endpoint for exactly ONE CQRS/ES operation.

## Structure

1. **Plan** — loads `plan-domain-endpoint` skill to scope the endpoint
2. **Implement** — loads TDD + endpoint implementation skills, builds the
   endpoint test-first

## Parameters

- `${parameters.operation}`: The exact domain operation name.

## What Gets Built

- Phoenix controller with `OpenApiSpex.ControllerSpecs`
- Router entry
- JSONAPI view
- OpenAPI response schemas (single + collection)
- Bruno API documentation
- All endpoint tests
