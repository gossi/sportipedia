---
name: parse-spec
description: Parse a spec markdown file and extract the ordered list of operations to build.
---

# Parse Spec

## Overview

Read a spec document and extract the list of operations (commands and queries) it
describes, grouped into feature slices, in build order.

**Executed by the builder directly.** This is deterministic extraction — pattern
matching over markdown, not judgement. Do not delegate it to a subagent.

## When to Use This Skill

Use this skill when:

- You are the builder starting the `spec` recipe
- You have been given a `spec_path`
- You need the operation list and the feature grouping to fan out over

## Input

You receive a `spec_path` parameter — the path to the spec markdown file.

## Steps

### Step 1: Read the Spec File

Read the spec file at `${spec_path}`.

### Step 2: Extract Commands

Find the `## Domain Model` section. Within it, identify all list items matching
the pattern `[Command: <name>]`. Extract each `<name>`.

Preserve the order they appear in the spec.

### Step 3: Extract Queries

Find the `## Domain Model` section. Within it, identify all list items matching
the pattern `[Query: <name>]`.

If no `[Query: ...]` entries exist, also scan:

- The `### Functional Requirements` subsection for lines mentioning "List" or
  "Read an" — these imply query operations
- The `### Integration Requirements` subsection for GET controller actions
  matching the pattern `→ :<action_name>` — these are queries

Convert snake_case action names to kebab-case (e.g. `list_apparatuses` →
`list-apparatuses`, `read_apparatus` → `read-apparatus`).

Preserve the order they appear in the spec.

### Step 4: Group into Feature Slices

Resolve each operation name to its ESDM file under `docs/domain-model/` and read
its `scope` block. Group operations by aggregate — that group is one **feature
slice**, and it is the unit of parallel execution.

Commands carry `scope.aggregate`. Queries do not — they carry `readModel`, which
names the same constituent. Use `scope.aggregate` for commands and `readModel` for
queries; a query whose read model matches an aggregate's slice belongs to that
slice. If a query's read model matches nothing, stop and report it — the model is
incomplete.

Operations on the same aggregate share `public_api.ex`, `policy.ex`,
`<object>_controller.ex`, `aggregate.ex`, `projector.ex` and the web router
scope. They must be built by one agent, serially. Never split an aggregate's
operations across slices.

Record the composite each slice lives in: slices in the same composite also share
the composite's commanded router.

### Step 5: Check the Spec's Own Links

The spec links to ESDM files with relative paths. Resolve each link in the
`## Domain Model` section against the spec file's directory and report any that
do not exist. These are usually a wrong `../` depth. Report them as a doc defect —
do not silently fix or ignore them, and do not let them change your extraction.

### Step 6: Return the Result

Return a JSON object:

```json
{
  "operations": ["catalog-apparatus", "edit-apparatus", "archive-apparatus", "read-apparatus", "list-apparatuses"],
  "features": [
    { "name": "apparatus", "composite": "equipment", "aggregate": "apparatus",
      "operations": ["catalog-apparatus", "edit-apparatus", "archive-apparatus", "read-apparatus", "list-apparatuses"] }
  ],
  "broken_links": ["## Domain Model → ../domain-model/catalog/equipment/aggregate.apparatus.esdm.yaml"]
}
```

Rules:

- `operations`: commands first, sorted by resulting database operation (create,
  update, delete), then queries in spec order.
- `features`: one entry per aggregate, each carrying its operations in the
  `operations` order above.
- Each operation name is the exact `name` property from the domain model.

## Verification

- [ ] Did I find ALL commands from the Domain Model section?
- [ ] Did I find ALL queries (from `[Query:]` entries, Functional Requirements,
      or Integration Requirements)?
- [ ] Are commands listed before queries?
- [ ] Does each group contain every operation of exactly one aggregate?
- [ ] Did I attempt to resolve every Domain Model link and report failures?
- [ ] Did I avoid extracting events, aggregates, read models, or actors as
      operations?
- [ ] Is the output valid JSON with `operations`, `features`, and `broken_links`?
