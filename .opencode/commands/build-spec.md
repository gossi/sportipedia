---
name: build-spec
description: Build a given spec — extract its operations, build each feature slice (in parallel by default), converge, commit per feature
agent: builder
---

# Build Spec: $1

Load the [spec recipe](@recipes/spec.recipe.md) and execute it.

Parameters:

- `${parameters.spec_path}` = `$1`

## Optional Flags

Parse these out of the invocation if present:

- `--serial` → `parallel: false` (build feature slices one at a time)
- `--max-concurrency <n>` → `max_concurrency: <n>`

Defaults: `parallel: true`. Keep concurrency within the Postgres connection
budget — `pool_size` is `schedulers * 2` per repo across two repos, so each
concurrent slice consumes roughly `schedulers * 4` connections when it runs tests.
Prefer letting slices run only their scoped tests and leaving the full suite to
`converge`.

## What Runs

1. You extract the operations yourself with the `parse-spec` skill — no subagent.
2. You preflight: leftover files, `mix compile --warnings-as-errors`, `esdm lint`.
3. One `domain-feature` slice per aggregate, in parallel. Each gets its own
   `MIX_TEST_PARTITION`.
4. You converge the shared registrations (`router.ex`, `application.ex`,
   `supervisor.ex`) by re-running the generators, then run the gates once.
5. One reviewer pass over the batch.
6. Commits are per feature, from each slice's `FILES:` list. Never `git add -A`.

Report the per-slice outcome table when the loop completes.
