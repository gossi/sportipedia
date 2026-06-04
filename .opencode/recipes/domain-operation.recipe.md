---
$schema: ./recipe.schema.yaml
name: domain-operation
description: Plan and implement a domain operation (command or query)
parameters:
  operation: { type: string, required: true, description: "Domain operation name" }
steps:
  - id: plan
    agent: software-architect
    skill: plan-domain-operation
    with: { operation: ${parameters.operation} }

  - id: implement
    agent: backend-engineer
    skills:
      - tdd
      - seek-implementation-for-domain-operation
      - seek-implementation-for-domain-operation-test
    with: { operation: ${parameters.operation} }
approval: auto
---

# Domain Operation Recipe

Plan and implement exactly ONE CQRS/ES operation in the Sportipedia domain.

## Structure

1. **Plan** — loads `plan-domain-operation` skill to scope and plan the
   implementation
2. **Implement** — loads TDD + implementation skills, builds the operation
   test-first

## Parameters

- `${parameters.operation}`: The exact domain operation name.

## What Gets Built

- Public API function
- Command or query module
- Command handler (for commands)
- Events (for commands)
- Aggregate (for commands)
- Projector (for commands)
- Read model
- Policy
- Validators and Queries (if needed)
- Internal API
- All tests
