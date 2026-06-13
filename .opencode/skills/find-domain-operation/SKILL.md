---
name: find-domain-operation
description: Find a read or write CQRS/ES operation in the Sportipedia domain.
---

# Find Domain Operation

## Overview

Find excatly ONE! domain feature for an endpoint to excatly ONE! CQRS/ES operation in the Sportipedia domain.

## When to Use This Skill

Use this skill when:

- You are about to work with a given domain operation.
- You need to know if the operation exists
- You need to learn more about that operation

## Success Criteria

We found exactly _one_ operation by exact match.
We cannot proceed if it is more than one operation or no operation.

Abort when this is not given.

## Figure out the Domain Operation

You can only run for exactly _one_ operation.
You should be given an explicit operation name (likely via parameter to that skill).

1. Get familiar with the [Domain Model](../../../docs/domain-model/README.md)
2. The given operation is either a query or a command
3. Find the operation by name (exact match)
   A) Operation is found, continue with [describe the operation](#operation-found)
   B) Operation is not found, continue with [operation not found](#operation-not-found)

## Operation Found

What to do when the operation is found

### Step 1: Find the Relevant Domain Models

- Find the relevant domain models to the given operation in the domain model

### Step 2: Identify the Operation and its sequence

Figure out if the given operation is a read or write operation

- Write: public API -> command -> command handler -> event -> apply state on aggregate -> projections -> read model
- Read: public API -> query -> read model

Specify and name the steps in the sequence:

- Identify the steps by name, use the identifiers from the domain model
- Discard anything that cannot be found in the domain model or is part of commanded, or the public API (entry file)

### Step 3: Announce the Operation

Summarize the feature you are about to implement:

- Which Subdomain we are in?
- Where in the subdomain are we (based on the architecture)
- What are the Domain models relevant for implementation
- Acknowledge the sequence to the user

## Operation not Found

There is a chance operations are not found, that's ok.
At this point we might have found something that comes close to the users request.
There might be search results available.

We must ask the user and clarify what they wanted to do.

- Case 1: Is it a typo?

  Clarify with the user what you found is the correct one

- Case 2: When search results are availabe?

  These are potential candidates, ask if it is one of them. Include the option it is one of them.

- Case 3: No search results are available?

  Ask if the user wanted something different or abort
