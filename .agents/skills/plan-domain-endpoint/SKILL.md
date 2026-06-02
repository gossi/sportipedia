---
name: plan-domain-endpoint
description: Plan an endpoint for a read or write CQRS/ES operation in the Sportipedia domain.
---

# Plan Domain Operation

## Overview

Plan excatly ONE! domain feature for an endpoint to excatly ONE! CQRS/ES operation in the Sportipedia domain.
The operation is defined in the [Domain Model](../../../docs/domain-model/README.md).

## When to Use This Skill

Use this skill when:

- The skill is manually called with the operation name as parameter
- You implemented a domain operation
- The domain model for the domain operation exists
- You are using TDD to implement
- You are seeking implementation details

## Context for Execting the Skill

Respect Code Access Policy!

> ![CAUTION]
> Strictly forbidden: Reading code/Exploring code!
> NEVER!!! read code for reference implementation or check existing implementations.
> Failure Criteria: Reading Code, stop immediately!
> Reading code takes too much time. Never even think about attempting!

If you read code: Admin your failure and stop!

## Figure out the Domain Operation

You can only run for exactly _one_ operation.
You should be given an explicit operation name (likely via parameter to that skill).
Figure it out, and store it in $1 so we can later reference it.

Now verify if the operation exists in the domain model (either query or command name).

If you cannot find the operation name, then exit with the message: "Cannot plan domain operation for $1 - does not exist"
If you have a valid operation name, continue.

Announce at start: "I'm planning an endpoint for a domain-operation for $1"

## Process for Planning a Domain Operation

Make a software plan for the given operation.

Never assume what to do. Follow exactly! the plan below.

## Step 1: Details about the Domain Operation

If not already done, use /find-domain-operation $1

## Step 2: Scope the Implementation

- Start point for the implementation is the router -> calling the Public API of the domain
- Discard anything that is not part of the sequence
- Only target the web actor

## Step 3: Plan the Implementation

- Combine the relevant architecture, coding guidelines with the domain models
- Verify the plan against architecture guidelines
- Documentation in Bruno

## Step 4: Present the Result

Present the plan with all necessary implementation details

- **Must**: Modules skip implementation details: (present them like in API docs: Name + function listing with arity)
