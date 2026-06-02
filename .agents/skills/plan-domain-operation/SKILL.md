---
name: plan-domain-operation
description: Plan a read or write CQRS/ES operation in the Sportipedia domain.
---

# Plan Domain Operation

## Overview

Plan excatly ONE! domain feature for a CQRS/ES operation in the Sportipedia domain.
The operation is defined in the [Domain Model](../../../docs/domain-model/README.md).

## When to Use This Skill

Use this skill when:

- The skill is manually called with the operation name as parameter
- The operation is known

## Before You Start — Mandatory Checklist

Answer these questions BEFORE writing any code. If any answer is "no" or "unsure", STOP and ask.

- [ ] Do I know EXACTLY which operation I'm implementing? (single command or query name)
- [ ] Do I have the domain model files for this operation?
- [ ] Can I list every file I need to create from the skill templates alone?
- [ ] Am I planning ONLY the named operation? (no read, list, edit, delete unless explicitly named)
- [ ] Do I have everything I need from documentation? (no code exploration required)

## Context for Executing the Skill

- [Respect Code Access Policy](../../code-access-policy.md) — **HARD CONSTRAINT**: Reading implementation code for patterns or reference is a task failure, not a warning. If violated: STOP, announce the violation, discard all knowledge from that code, and restart from documentation.
- This skill counts as documentation — it is sufficient for implementation
- DO NOT run discovery, DO NOT explore code

> ![CAUTION]
> Strictly forbidden: Reading code/Exploring code!
> NEVER!!! read code for reference implementation or check existing implementations.
> Failure Criteria: Reading Code, stop immediately!
> Reading code takes too much time. Never even think about attempting!

If you read code: Admit your failure and stop!

### Templates Are Complete

The code templates in this skill contain EVERYTHING you need.
You do NOT need to:
- Look at existing implementations for patterns
- Explore the codebase for conventions
- Verify against existing code

If a template seems incomplete, that is a documentation gap — report it, do not fill it from code.

## Figure out the Domain Operation

You can only run for exactly _one_ operation.
You should be given an explicit operation name (likely via parameter to that skill).
Figure it out, and store it in $1 so we can later reference it.

Now verify if the operation exists in the domain model (either query or command name).

If you cannot find the operation name, then exit with the message: "Cannot plan domain operation for $1 - does not exist"
If you have a valid operation name, continue.

Announce at start: "I'm planning a domain-operation for $1"

## Process for Planning a Domain Operation

Make a software plan for the given operation.

Never assume what to do. Follow exactly! the plan below.

## Step 1: Details about the Domain Operation

If not already done, use /find-domain-operation $1

## Step 2: Scope the Implementation

- Start point for the implementation is the public API / Port
- Discard anything that is not part of the sequence
- Only target the domain actor

## Step 3: Plan the Implementation

- Only implement the sequence specified in the previous step
- Include the policy for the given operation
- Combine the relevant architecture, coding guidelines with the domain models
- Look into the seek-implementation-for-domain-operation skill to understand what it _can_ build and _might_ use
- Verify the plan against architecture guidelines

## Step 4: Present the Result

Present the plan with all necessary implementation details

- **Must**: Modules skip implementation details: (present them like in API docs: Name + function listing with arity)

## Verification — Before Declaring Done

Check each item. If any is "no", you have scope creep:

- [ ] Did I plan files ONLY for the named operation?
- [ ] Are there any operations beyond the one requested?
- [ ] Did I read any implementation files? (should be: no)
- [ ] Did I follow directory structure from docs, not from existing code?
