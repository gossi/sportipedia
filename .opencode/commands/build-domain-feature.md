---
name: build-domain-feature
description: Build a complete feature slice — every operation of one aggregate, domain and web actors, in one plan/implement/review
agent: builder
---

# Build Domain Feature: $1

Load the [domain-feature recipe](@recipes/domain-feature.recipe.md) and execute it.

Parameters:

- `${parameters.feature}` = `$1` — the constituent / aggregate name (e.g. `position`)
- `${parameters.spec_path}` = `$2` — optional; the governing spec if one exists

## Resolve Before Delegating (builder-side, deterministic)

The recipe needs the slice's operation list. Find it yourself instead of asking a
subagent:

1. Search `docs/domain-model/**` for `kind: command` and `kind: query` files whose
   `scope.aggregate` matches `$1`.
2. Order them: commands by database effect (create, update, delete), then queries.
3. Take the `scope.boundedContext` and the file's directory for `composite`.
4. If the aggregate matches nothing, stop and report it — there is no slice to
   build.

Bind `${parameters.operations}` to that list.

## Notes

- One architect call plans the whole slice; one engineer implements all of it; one
  reviewer reviews it as a unit. This is ~4 calls, not one round per operation.
- The plan carries decisions only — cross-boundary calls, invariant realization,
  error atoms, actor mapping, model gaps, migration content, residuals. No module
  table, no file paths, no generator order.
- You run the gates and the commit. Pass the `MIX_TEST_PARTITION` matching the
  feature name when running in parallel with other slices.
- No other slice's work belongs here: the boundary is enforced in the delegation
  prompt, not by hoping the generators behave.
