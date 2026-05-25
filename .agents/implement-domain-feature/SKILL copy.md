---
name: implement-domain-feature
description: Implement a vertical-slice feature for a CQRS/ES operation in the Sportipedia domain.
---

# Implement Domain Feature

## Overview

Implement ONE! domain feature for a CQRS/ES operation in the Sportipedia domain. The feature is defined in the [Domain Model](../../../docs/domain-model/README.md).

Implement the vertical slice of read or write feature.

- Write feature: public API -> command -> command handler -> event -> apply state on aggregate -> projections -> read model
- Read feature: public API -> query -> read model

Context: This should be run when a product specifiaction is ready for implementation.

## When to Use This Skill

Use this skill when:

- You finished writing a product specification, product spec
- You have defined a domain model
- You have a clear definition of what needs to be implemented

## Process for Implementing a Domain Feature

Follow this process to elicit the necessary information and write accurate code.

### Step 1: Make yourself familiar

- Understand the [Architecture](../../../ARCHITECTURE.md)
- Understand the [Coding Guidelines](../../../docs/coding-guidelines/README.md) (follow into relevant subsections)
- Understand the [Domain Model](../../../docs/domain-model/README.md)
- Understand the used backend [frameworks and libraries](../../../docs/references/third-party-libraries.md)

### Step 2: Find the Relevant Domain Models

- The feature only requires a subset from the domain model
- Find the relevant ones for the feature
- Summarize the feature you are about to implement:
  - Which Subdomain we are in?
  - Where in the subdomain are we (based on the architecture)
  - What are the Domain models relevant for implementation

### Step 3: Plan the Implementation

- Combine the relevant architecture, coding guidelines with the domain models
- Make a detailed plan, which files are created and what they contain
- Verify the plan against architecture guidelines
- Summarize the plan: File + outline of its contents (including the proper naming)

### Step 4: Write Code

Respect the following guidelines. The code will use the commanded framework

#### Policy

- Policy uses the bodyguard framework
- One function per policy

#### Command

- Struct creation with enforced fields
  - use TypedStruct
  - use ExConstructor
- Validation (if applicable)
  - use Vex.Struct

#### Command Handler

- Takes the command as input
- Outputs events
- Can be as simple as mapping the command to the events or complex handling a bunch of business logic

#### Events

- Struct creation with enforced fields
  - use TypedStruct
  - use ExConstructor

#### Evolve State

- apply function on the aggregate

#### ReadModel

- Struct creation with enforced fields
  - Use TypedEctoSchema
  - Ecto.Changeset
- Write necessary changeset functions

#### Projection

- `project` macro on the Projector
- use changeset functions from read model (if applicable)

#### Queries (if needed)

- read one model: not needed, use ecto
- list many models: not needed, use `Sportipedia.Support.JSONAPI.QueryBuilder`
- all others: own module per query with Ecto.Query

#### Public API

- One function per command
- One function per query
