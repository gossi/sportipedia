---
name: write-product-spec
description: Use when asked to design a new feature or project
---

# Writing Product Specifications

## Overview

Write comprehensive product specification documents that clearly communicate what we're building, why we're building it, and how we'll know it's successful. Document everything stakeholders need to understand: the problem context, requirements and tradeoffs. Give them a complete picture of the feature or project.

Assume the reader is a skilled product person or engineer, but knows nothing about this specific feature or the problem domain. Assume they need clear context to understand the "why" behind the work.

Make yourself familiar with the given [Architecture](../../../ARCHITECTURE.md) and [Domain Model](../../../docs/domain-model/README.md)

Connect the product specification document with [ESDM](https://www.esdm.io). Link the spec to the esdm yaml files.

Announce at start: "I'm using the writing-product-specs skill to create the product specification."

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
- **How will this feature/project solve them?** What is the proposed solution? How does it address the problems? What are the commands and events? Which aggregates do these affect? What are the projections to which read model? Quality assurance in the form of Given-When-Then.
- **Is there a reference implementation?** Found a reference implementation, ask if this is correct? Fully or which parts? Explicitely include partially as answer
- **Is the Domain Model defined?** Are the additions clear and distinctively described? Are there (no) ambiguities?
- **Explicitely! ask this question (include your assumptions): What are the invariants?** Do we know the rules that apply? Is existing prior prior knowledge still accurate?
- **What are we NOT doing?** What is explicitly out of scope? What related features or capabilities are we excluding?
- **What needs to be documented through code?** Bruno collection? Storybook?

Continue asking questions until you have enough information to draft a complete spec. Don't proceed to drafting until you have clear answers to these core questions.

### Step 2: Draft the Specification

Using the information gathered, draft the product specification following the document structure outlined in the **Product Spec Format** section. Present the complete draft to the user.

### Step 3: Iterate Based on Feedback

After presenting the draft:
- Ask the user for edits, clarifications, or additions
- Identify gaps in the spec and ask targeted questions to fill them
- Revise the spec based on feedback
- Continue iterating until the user confirms the spec is complete and accurate

### Step 4: Finalize and Save

Once the user confirms the spec is good enough:
- Review the final spec against the document structure in **Product Spec Format**
- Extract the additions to the domain model into their own `*.esdm.yaml` files
  - Make use of the Given-When-Then extension
- Link them from the spec
- Save the artifact as `spec-<feature-name>-DD-MM-YYYY.md` (or as requested by the user). Put the file under /docs/specs/ then follow the same directory structure as the architecture does for the given subdomain we are in.

## Product Spec Format

Below is the format for a product spec. Each section should be written with clear, actionable guidance.

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

## Requirements

**Instructions:** List what is necessary for us to build in order to solve this problem. Be specific about functional requirements, technical requirements, and constraints. Organize by priority or category if helpful. Each requirement should be clear enough that an engineer can understand what needs to be built. 

**Must**: Strictly stay to the following order

**What to include:**
- Functional requirements (what the system/feature must do)
- Technical requirements (performance, scalability, compatibility needs)
  - Highest priority is the given Architecture
  - Then documentation from the used library/frameworks
  - Then a verified reference implementation
- User experience requirements (if applicable)
- Integration or dependency requirements
- Documentation (what code-related documentation needs to be written)

**What NOT to include:**
- Reference to existing implementations, make it ALWAYS based on Architecturre

## Non-requirements

**Instructions:** Explicitly state what we are not doing, what is out of scope, and what we don't have to do. This prevents scope creep and sets clear boundaries. Be specific about related features or capabilities that might seem related but are explicitly excluded.

**What to include:**
- Features or capabilities explicitly out of scope
- Related problems we are not solving
- Future work that might seem related but isn't part of this spec
- Assumptions about what we don't need to build

## Quality Assurance

**Instructions:** Explain the criteria that verify the feature implementation is correct. 

**Must**: Strictly stay to the following order

**What to include:**
- Test Scenarios
  - Given
  - When
  - Then
  - Include the terminology from the used domain model
  - **Must** reference the domain-model file including the scenario by name
- Implementation Tests

## Tradeoffs and concerns

**Instructions:** When you write this section just include the placeholder below in italics.

    Especially from engineering, what hard decisions will we have to make in order to implement this solution? What future problems might we have to solve because we chose to implement this?