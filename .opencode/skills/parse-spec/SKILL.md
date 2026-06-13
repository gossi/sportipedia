---
name: parse-spec
description: Parse a spec markdown file and extract the ordered list of operations to build.
---

# Parse Spec

## Overview

Read a spec document and extract the list of operations (commands and queries) it describes, in build order.

## When to Use This Skill

Use this skill when:
- You are the Product Owner subagent in a spec build workflow
- You have been given a spec file path
- You need to tell the builder which operations exist and in what order to build them

## Input

You receive a `spec_path` parameter — the absolute or relative path to the spec markdown file.

## Steps

### Step 1: Read the Spec File

Read the spec file at `${spec_path}`.

### Step 2: Extract Commands

Find the `## Domain Model` section of the spec. Within it, identify all list items matching the pattern `[Command: <name>]`. Extract each `<name>`.

Preserve the order they appear in the spec.

### Step 3: Extract Queries

Find the `## Domain Model` section of the spec. Within it, identify all list items matching the pattern `[Query: <name>]`.

If no `[Query: ...]` entries exist, also scan:
- The `### Functional Requirements` subsection for lines mentioning "List" or "Read an" — these imply query operations
- The `### Integration Requirements` subsection for GET controller actions matching the pattern `→ :<action_name>` — these are queries

Convert snake_case action names to kebab-case (e.g., `list_apparatuses` → `list-apparatuses`, `read_apparatus` → `read-apparatus`).

Preserve the order they appear in the spec.

### Step 4: Return Operations List

Return the result as a JSON object with a single key `operations` containing the ordered list:

```json
{
  "operations": ["catalog-apparatus", "edit-apparatus", "archive-apparatus", "read-apparatus", "list-apparatuses"]
}
```

Rules:
- Commands first, sort them by their resulting database operations (if any): create, update, delete
- Queries second, in the order they appear in the spec
- Each operation name is the exact string from the `name` property in the domain model

## Verification

- [ ] Did I find ALL commands from the Domain Model section?
- [ ] Did I find ALL queries (either from [Query:] entries, Functional Requirements, or Integration Requirements)?
- [ ] Are commands listed before queries?
- [ ] Does the order within each group match the spec's section order?
- [ ] Did I avoid extracting events, aggregates, read models, or actors as operations?
- [ ] Is the output valid JSON with the `operations` key?
