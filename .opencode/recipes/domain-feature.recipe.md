---
$schema: ./recipe.schema.yaml
name: domain-feature
description: Build a complete domain feature (operation + endpoint)
parameters:
  operation: { type: string, required: true, description: "Domain operation name" }
steps:
  - id: find
    agent: software-architect
    skill: find-domain-operation
    with: { operation: ${parameters.operation} }

  - id: build-operation
    recipe: domain-operation
    with: { operation: ${parameters.operation} }

  - id: build-endpoint
    recipe: domain-endpoint
    with: { operation: ${parameters.operation} }

  - id: review-loop
    loop:
      max: 3
      steps:
        - agent: reviewer
          exit-when: ${result.review.status} == "pass"
        - agent: backend-engineer
          skills:
            - tdd
            - use-blueprints
          with: { operation: ${parameters.operation} }
approval: auto
---

# Domain Feature Recipe

Build a complete CQRS/ES operation including its web endpoint, views, schemas,
routing, and API documentation.

## Structure

This recipe composes three sub-recipes:

1. **Find operation** — verifies the operation exists in the domain model
2. **Domain operation** — plans and implements the CQRS/ES operation (command
   or query, event, aggregate, projection, read model, policy)
3. **Endpoint** — plans and implements the web endpoint (controller, router,
   view, OpenAPI schemas, Bruno docs)
4. **Review** — verifies the implementation against architecture and security
   guidelines

## Parameters

- `${parameters.operation}`: The exact domain operation name (command or query)
  as defined in the domain model.

## Handoff

The final artifact is a complete vertical slice: operation + endpoint + tests + docs.
