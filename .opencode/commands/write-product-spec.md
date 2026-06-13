---
name: write-product-spec
description: Use when asked to design a new feature or project
agent: product-specialist
---

# Writing Product Specifications

## Overview

Write comprehensive product specification documents that clearly communicate what we're building, why we're building it, and how we'll know it's successful. Document everything stakeholders need to understand: the problem context, requirements and tradeoffs. Give them a complete picture of the feature or project.

Assume the reader is a skilled product person or engineer, but knows nothing about this specific feature or the problem domain. Assume they need clear context to understand the "why" behind the work.

Make yourself familiar with the given [Architecture](../../../ARCHITECTURE.md) and [Domain Model](../../../docs/domain-model/README.md)

Connect the product specification document with [ESDM](https://www.esdm.io). Link the spec to the esdm yaml files.

Context: This should be run when designing a new feature or planning a project that needs clear requirements documentation.

**Core principle:** Product specifications are detailed descriptions of the features and functionality of a product. They are used to communicate the requirements of the product to the development team.

## When to Use This Skill

Use this skill when:

- You are explicitly asked to write a product specification, product spec, or PRD (Product Requirements Document)
- You are asked to design a new feature and need to document requirements before implementation
- You are planning a project and need to define what will be built and why
- You need to communicate product requirements to stakeholders, engineers, or designers
- A feature request needs to be expanded into a detailed specification with context, requirements, and success criteria
- You are asked to document the "what" and "why" of a product decision before moving to implementation

## Process for Writing a Product Spec

Follow this process to elicit the necessary information and compose a comprehensive product specification.

### Step 1: Understand the Requested Feature or Project

Ask questions to understand the feature or project. There might be prior knowledge in the domain-model. While asking questions, check if you can find existing information and verify them with the user. Gather information about:

- **What is it?** What feature or project are we building? What does it do?
- **What are their problems?** What specific pain points or challenges does the audience face? What is broken or missing?
- **Where is the problem located?** What subdomain, composite and constituent we are in?
- **What architectural scope does this cover?** Is this backend-only, full-stack, domain-only, or something else?
- **How will this feature/project solve them?** What is the proposed solution? How does it address the problems? What are the commands and events? Which aggregates do these affect? What are the projections to which read model? Quality assurance in the form of Given-When-Then.
- **Is the Domain Model defined?** Check the existing domain model for consistency. If anything is missing or ambiguous, fill the gaps through domain modelling.
- **Explicitely! ask this question (include your assumptions): What are the invariants?** Do we know the rules that apply? Is existing prior knowledge still accurate?
- **What are we NOT doing?** What is explicitly out of scope? What related features or capabilities are we excluding?

As you discuss the feature, keep an ear out for things that feel like they should be deferred or pushed out of scope — cross-aggregate dependencies, prerequisite conditions, scope-creep risks. Flag these conversationally and decide together whether to defer them (→ todo file) or exclude them (→ non-requirements).

Continue asking questions until you have enough information to draft a complete spec. Don't proceed to drafting until you have clear answers to these core questions.

### Step 2: Domain Modelling

Interview to define the domain model precisely:

- Commands and their data fields (required vs optional)
- Events and their payloads
- Aggregate state and invariants
- Read models and projections
- Authorization rules per actor
- Given-When-Then Feature with scenarios
- **Behavior** — what happens when the command executes, how partial updates work, what the event payload contains and under what conditions. Capture this as detail in the ESDM `description` field.

Write/update the `*.esdm.yaml` files under `docs/domain-model/<subdomain>/<composite>/`. Then run:

```bash
esdm lint
```

Loop: fix any errors → re-lint → repeat until clean. Warnings may be ignored.

If the domain model was previously defined and is consistent, this step validates and confirms it.

### Step 3: Draft and Iterate the Specification

Using the information gathered and the validated domain model, draft the product specification following the document structure outlined in the **Product Spec Format** section. Present the complete draft to the user.

After presenting the draft:

- Ask the user for edits, clarifications, or additions
- Identify gaps in the spec and ask targeted questions to fill them
- Revise the spec based on feedback
- If feedback touches the domain model, return to Step 2
- Continue iterating until the user confirms the spec is complete and accurate

### Step 4: Finalize and Save

Once the user confirms the spec is good enough:

- Review the final spec against the document structure in **Product Spec Format**
- Create a `_todo/todo-<feature>-DD-MM-YYYY.md` file for any deferred items (linked from the Tradeoffs section)
- Link the spec to the ESDM files
- Save the artifact as `spec-<feature>-DD-MM-YYYY.md` (or as requested by the user). Put the file under `/docs/specs/` then follow the same directory structure as the architecture does for the given subdomain we are in.

## Product Spec Format

Below is the format for a product spec. Each section should be written with clear, actionable guidance.

```yaml
---
feature: <name of the feature, same as in the filename>
subdomain: <subdomain>
composite: <copmosite>
constituent: <consitutent>
scope: backend and/or frontend
---
```

# [Project / Feature Title]

**Instructions:** Provide a brief (1-2 sentences max) description of what we are building. This is the tl;dr that should explain the entire project and its benefits in a few sentences. A reader should understand the core value proposition from this title and description alone.

**What to include:**

- Clear, descriptive title that captures the feature/project
- One to two sentences summarizing what is being built
- The primary benefit or value this delivers

## Background

### Context

**Instructions:** Describe the world the problem exists in and the problem in broad strokes. Set the stage for why this work matters. Explain the current state, what's happening in the market or user workflows, and why this problem has emerged or become important now.

**What to include:**

- Current state of the world/workflow/system
- Why this problem exists or has become relevant
- Any relevant trends, constraints, or external factors
- The gap between current state and desired state

### Problem Statements

**Instructions:** List the specific problems we are solving. Use bullet format, one problem per bullet. Be succinct and direct—the background context has already been established. Each problem statement should be clear, specific, and actionable.

**What to include:**

- Each problem as a separate bullet point
- Specific, concrete problems (avoid vague statements)
- Problems that are directly addressable by the solution
- Focus on user pain points or business needs

## Domain Model

**Instructions:** List the used domain model for the given feature. Link what already exists. Explain what is new. Strictly document this with the given template below.

**What to include:**

- Commands and Events
- Aggregates they operate on
- Projections into read models
- Read models and queries
- Authorization/Permissions
- Given-When-Then Feature + Scenarios

**Use this example (only sections that apply):**

```
Used Domain Models:

- [Type: Name](../path/to/file.esdm.yaml): Purpose

Modified Domain Models:

- [Type: Name](../path/to/file.esdm.yaml): Purpose

New Domain Models:

- [Type: Name](../path/to/file.esdm.yaml): Purpose
```

## Additional Requirements

**Instructions:** Capture what needs to be built that the domain model (ESDM files) and implementation skills do not already define. Behavioural detail for commands and events belongs in the ESDM `description` field — do not duplicate it here. This section is for deviations from standard patterns, decisions no skill covers, and scope-specific needs.

**Must**: Strictly stay to the following order

**What to include:**

- Functional requirements — capabilities beyond what the domain model express
- Technical requirements — deviations from standard architecture, or technical needs no existing guide covers
- Integration or dependency requirements (business-level decisions)
- User experience requirements (if applicable)

## Non-requirements

**Instructions:** Explicitly state what we are not doing, what is out of scope, and what we don't have to do. This prevents scope creep and sets clear boundaries. Be specific about related features or capabilities that might seem related but are explicitly excluded.

**What to include:**

- Features or capabilities explicitly out of scope
- Related problems we are not solving
- Future work that might seem related but isn't part of this spec
- Assumptions about what we don't need to build

## Quality Assurance

**Instructions:** Explain the criteria that verify the feature implementation is correct.

**What to include:**

- Test Scenarios
  - Given
  - When
  - Then
  - Include the terminology from the used domain model
  - **Must** reference the domain-model file including the scenario by name

## Tradeoffs and Concerns

**Instructions:** Document the hard decisions, deferred work, and their consequences. Use the following structure for each tradeoff:

### [Title of the tradeoff/deferred decision]

- **What:** What decision was made or deferred?
- **Why:** Why was it done this way?
- **Consequence:** What does this mean for correctness, users, or future work?
- **Follow-up:** Link to the todo file in `docs/specs/_todo/`
