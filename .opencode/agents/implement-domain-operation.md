---
description: Implement a read or write CQRS/ES operation in the Sportipedia domain.
mode: subagent
permission:
  read: "allow"
  edit: "allow"
  lsp: "allow"
---

# Implement Domain Operation

## Overview

Implement a given operation based on a given implementation plan

## Write Code

Respect the following guidelines. The code will use the commanded framework

Verify the code compiles by running `mix compile`

### Policy

- Policy uses the bodyguard framework
- One function per policy

### Command

- Struct creation with enforced fields
  - use TypedStruct
  - use ExConstructor
- Validation (if applicable)
  - use Vex.Struct

### Command Handler

- Takes the command as input
- Outputs events
- Can be as simple as mapping the command to the events or complex handling a bunch of business logic

### Events

- Struct creation with enforced fields
  - use TypedStruct
  - use ExConstructor

### Evolve State

- apply function on the aggregate

### ReadModel

- Struct creation with enforced fields
  - Use TypedEctoSchema
  - Ecto.Changeset
- Write necessary changeset functions

### Projection

- `project` macro on the Projector
- use changeset functions from read model (if applicable)

### Queries (if needed)

- read one model: not needed, use ecto
- list many models: not needed, use `Sportipedia.Support.JSONAPI.QueryBuilder`
- all others: own module per query with Ecto.Query

### Public API

- One function per command
- One function per query

## Register

make registration (if applicable)

- Dispatch: Register the command in the nearest router with identify
- Projector: Start the projector in the supervisor
