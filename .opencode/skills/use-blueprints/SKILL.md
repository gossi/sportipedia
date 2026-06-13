---
name: use-blueprints
description: Make use of blueprints when generating code
---

# Use Blueprints

Blueprints are part of Sportipedia's software architecture.
When generating code and there is a blueprint available, then use it.

## Learn Blueprints

Blueprints are here, so you don't need to gather all information by yourself, they are all already in one place.

[Read more about why blueprints are vital and how they help](../../../docs/architecture/blueprints/README.md)

## Context for Using Blueprints

Recite the design goals for the blueprints and the context for using them.
At this point there is no time to become creative:

- [Respect Code Access Policy](../../code-access-policy.md)
  — **HARD CONSTRAINT**: Reading implementation code for patterns or reference is a task failure, not a warning. If violated: STOP, announce the violation, discard all knowledge from that code, and restart from documentation.
  - This skill counts as documentation — it is sufficient for implementation
  - DO NOT run discovery, DO NOT explore code

  > ![CAUTION]
  > Strictly forbidden: Reading code/Exploring code!
  > NEVER!!! read code for reference implementation or check existing implementations.
  > Failure Criteria: Reading Code, stop immediately!
  > Reading code takes too much time. Never even think about attempting!

- The blueprints have code templates or even examples
- Find which examples are applicable
- Use them, this is important to comply with the architecture design
