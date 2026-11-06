---
name: build-domain-operation
description: Build the domain operation for exactly one command or query (single-operation entry point; repairs, not fresh aggregates)
agent: builder
---

# Build Domain Operation: $1

Load the [domain-operation recipe](@recipes/domain-operation.recipe.md) and execute it.

Parameters:

- `${parameters.operation}` = `$1`
- `${parameters.spec_path}` = `$2` — optional

## Notes

Follows the same rules as `build-domain-feature`, scoped to one operation:

- One architect plan (decisions only — no module table, no file paths, no
  generator order), one implementer, one reviewer, up to 3 review attempts.
- No `find-domain-operation` step: the generators fail loudly on an unknown name.
- You run the gates and the commit yourself. The subagent ends its response with
  `FILES:`; commit exactly that list, never `git add -A`.
- Domain actor only — controller, view, schema, web route and Bruno belong to
  `build-domain-endpoint`.
- Pass the spec by **path**, never by pasted content.

Prefer `build-domain-feature` for a fresh aggregate: it loads the shared scaffold
once and reviews the slice as a whole, which is where cross-operation
contamination shows up.
