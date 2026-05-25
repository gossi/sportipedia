---
name: implement-domain-operation
description: Implement a read or write CQRS/ES operation in the Sportipedia domain.
---

# Implement Domain Operation

## Overview

Implement excatly ONE! domain feature for a CQRS/ES operation in the Sportipedia domain. 
The operation is defined in the [Domain Model](../../../docs/domain-model/README.md).

Context: This should be run when a plan for that operation is ready for implementation.

## When to Use This Skill

Use this skill when:

- You have a plan for implementing a domain operation
- The operation is known

## Context for Execting the Skill

Respect Code Access Policy!

> ![CAUTION]
> NEVER!!! read code for reference implementation or check existing implementations.
> Failure Criteria: Reading Code, stop immediately!

## Figure out the Domain Operation

You can only run for exactly _one_ operation.
You should be given an explicit operation name.
Figure it out, and store it in $1 so we can later reference it.

Now verify if the operation exists in the domain model (either query or command name).

If you cannot find the operation name, then exit with the message: "Cannot implement domain operation for $1 - does not exist"
If you have a valid operation name, continue.

Announce at start: "I'm implementing a domain-operation for $1"

## Process for Implementing a Domain Operation

- Implement the contents of the passed plan. No more, no less!

    If the plan cannot be implemented as written (e.g., a referenced module, function, or type does not exist), stop and flag the discrepancy. Do not silently correct the plan, do not add functionality beyond what is specified, and do not change signatures or dispatch targets without first reporting the issue.

- Verify the code compiles by running `mix compile`
- The code will use the commanded framework
- Respect the following guidelines for each citizen

### Policy

Derive authorization from the domain model and present rules and invariants.

- Policy uses the bodyguard framework
- Only functions for $1

### Command

Read command from the domain model and present rules and invariants.

- Struct creation with enforced fields
  - use TypedStruct
  - use ExConstructor
- Validation (if applicable)
  - use Vex.Struct
  - may write custom validators for invariants

### Command Handler

Implement the actual command behavior. 

- Takes the command as input
- Outputs events
- Can be as simple as mapping the command to the events or complex handling a bunch of business logic
  - See if invariants from the aggregate must be respected (if not already somewhere else).

### Events

Read event from the domain model and present rules and invariants

- Struct creation with enforced fields
  - use TypedStruct
  - use ExConstructor

### Evolve State

- apply function on the aggregate

### ReadModel

Read read-model from the domain model and present rules and invariants

- Struct creation with enforced fields
  - Use TypedEctoSchema
  - Ecto.Changeset
- Write necessary changeset function for this operation

### Projection

Derive from read-model the applicable rules and invariants and present them.

- Projector uses `commanded_ecto_projections`
- `project` macro on the Projector
- use changeset functions from read model (if applicable)

### Queries (if needed)

- read one model: not needed, use ecto
- list many models: not needed, use `Sportipedia.Support.JSONAPI.QueryBuilder`
- all others: own module per query with Ecto.Query

### Public API

- One function per command
- One function per query

#### Command

- Dispatches the command with strong consistency
- Vex runs as commanded middleware and validates the command
- If the command results in a CREATE projection, instantiate a UUID for it
- If the command addresses a read model, return it
- Unless the command resuslts in DELETE projection, then don't

#### Query

- Query Ecto for the read model
- read one model: use `Repo.get`
- list many models: use `Repo.all` with `Sportipedia.Support.JSONAPI.QueryBuilder`
- all others: use the respective custom query

## Register

make registration (if applicable)

- Dispatch: Register the command in the nearest router with identify
- Projector: Start the projector in the supervisor
