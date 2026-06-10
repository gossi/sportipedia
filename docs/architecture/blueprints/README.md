# Blueprints

Blueprints are a vital part of architecture design for Sportipedia.

## Design Goals

- They are designed to ensure quality standards amongst the codebase
- They are designed so code changes are _cheap_ by following the same standards
  everywhere
- One function doing one thing but in different places shall give the same look
  for a _human_ to feel "at home"
- Coding agents thus must strictly follow them, to achieve the design goals
- Code may age, but blueprints are the source of truth
- Blueprints can drive refactorings, aged code can't

## Context for Using Blueprints

- [Read Architecture Documentation](../../../ARCHITECTURE.md)
- [Read Placeholder Naming Substitution](../naming-substitution.md)
- [Respect Coding Guidelines](../../coding-guidelines/README.md)

## Blueprint Structure

The blueprints follow a structure

1. Name (first heading)
2. Table with relevant metadata
3. (Prerequiste)
4. Implementation
5. Tests

_Prerequisite_ list things required to apply this blueprint.

_Implementation_ sections includes information to implement a particular
functionality. Blueprint + domain model is 99% the information that is
needed to implement the functionality. The last 1% is found in the specification
of a particular feature (this is known upfront).
As part of instructions, usually blueprints contain an implementation template
to scaffold the implementation. Even examples are there to represent common functionality.

_Tests_ have information what to use to write the tests for the functionality.
Usually this also includes _what_ and _how_ to test.

With both _implementation_ and _test_ given, this allows for
test-driven-development (tdd).

### Code Templates

- Code Templates give you a scaffolding, when creating the file from scratch
- They are templates, not strict guidelines
- Sorting functions in modules when they contain both queries and commands:
  1. All commands
  2. All queries

## Available Blueprints

Here: [/docs/architecture/blueprints/](../../../docs/architecture/blueprints/)
