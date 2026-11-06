---
$schema: ./recipe.schema.yaml
name: spec
description: Build everything described in a spec document — extract operations, fan out feature slices in parallel, converge shared registrations, commit per feature
parameters:
  spec_path:
    type: string
    required: true
    description: "Path to the spec markdown file (e.g., docs/specs/catalog/equipment/spec-manage-apparatuses-19-05-2026.md)"
  parallel:
    type: boolean
    required: false
    description: "Run feature slices concurrently. Defaults to true. When false, execute the loop serially despite the step's mode: parallel."
  max_concurrency:
    type: number
    required: false
    description: "Cap on simultaneous feature slices. Respect the Postgres connection budget."
steps:
  - id: parse
    builder: parse-operations
    with: { spec_path: "${parameters.spec_path}" }

  - id: preflight
    builder: preflight

  - id: build-features
    loop:
      over: ${steps.parse.result.features}
      mode: parallel
      max-concurrency: ${parameters.max_concurrency}
      steps:
        - recipe: domain-feature
          with:
            spec_path: ${parameters.spec_path}
            feature: ${item.name}
            composite: ${item.composite}
            operations: ${item.operations}
            partition: ${item.name}

  - id: converge
    builder: converge
    with: { features: "${steps.parse.result.features}" }

  - id: batch-review
    agent: reviewer
    with:
      scope: batch
      spec_path: ${parameters.spec_path}
      features: ${steps.parse.result.features}
      convergence: ${steps.converge.result}

  - id: report
    builder: report
approval: auto
---

# Build Spec Recipe

Build a complete spec: extract its operations, group them into feature slices by
aggregate, build each slice, then converge and commit.

## Structure

1. **Parse** *(builder, deterministic)* — load `parse-spec` and run it yourself.
   Do not delegate extraction to a subagent. It returns the ordered `operations`,
   the `features` groups, and any `broken_links` in the spec.
2. **Preflight** *(builder, deterministic)* — establish a baseline before any
   agent writes a file. See below.
3. **Build features** — for each aggregate, one `domain-feature` sub-recipe.
   Slices run **concurrently** by default; each gets its own database partition.
4. **Converge** *(builder, deterministic)* — repair shared registrations that
   concurrent slices stomped on, then run the gates once.
5. **Batch review** — one reviewer pass over the whole converged tree.
6. **Report** — per-slice outcome table.

## Why the Feature Slice Is the Unit of Parallelism

Operations on one aggregate share `public_api.ex`, `policy.ex`,
`<object>_controller.ex`, `aggregate.ex`, `projector.ex`, `read_model.ex` and a
router scope. Two agents editing those concurrently corrupt each other, and the
damage is invisible until the build breaks. One agent per aggregate builds all of
its operations serially and loads the shared scaffold once — which is also why
this is ~4 calls per feature instead of ~9 per operation.

Across aggregates, the collision surface shrinks to three files:

- `services/api/lib/sportipedia_web/router.ex` — **one global file, every slice**
- `services/api/lib/sportipedia/<subdomain>/application.ex`
- `services/api/lib/sportipedia/<subdomain>/supervisor.ex`
- plus `services/api/lib/sportipedia/<subdomain>/<composite>/router.ex` for
  slices sharing a composite (`apparatus` and `instrument` do)

This recipe does **not** prevent those collisions. It repairs them, because
`SpGen.Merge` is append-only, never rewrites existing nodes, and `sp.gen … --check`
reports divergence. Regeneration converges; that is cheaper than locking, and it
survives an interrupted run.

## Builder Execution Rules

### Pass Artifacts by Reference

Never paste spec or plan contents into a subagent prompt. Subagents have read
access to `docs/**`. Give them the **path** and let them read it. The only
artifact that crosses the boundary by value is the plan, once per slice, because
the plan is deliberately not written to disk.

### Spec Context

Every delegation carries:

- the spec path, and the domain-model path
- the slice boundary: "this slice contains ONLY `<operations>`"
- the instruction: *if you hit ambiguous business logic, output
  `QUESTION: <question>` and stop*

### FILES Contract

Every implementing subagent MUST end its response with:

```
FILES:
  <repo-relative path>
  ...
```

The builder unions that list with the paths spgen's own run report printed. This
list is what gets committed — `git add -A` is forbidden anywhere in this recipe.

### Database Partitioning

Each concurrent slice exports `MIX_TEST_PARTITION=<feature>` and creates its own
`sportipedia_test_<feature>` database. Without this, one agent's `ecto.reset`
destroys another's running tests. Connection budget: `pool_size` is
`schedulers * 2` per repo across two repos, so cap `max_concurrency` accordingly
or have slices run only their own scoped tests and leave the full suite to
converge.

### Commits Are Per Feature, and Builder-Only

Subagents never run git. The builder is the single writer to the index, so
`index.lock` races cannot occur. As each slice lands and passes review, commit
exactly its file list:

```
git add <paths from FILES>
git commit -m "Implement <feature>: <operations>"
```

Whoever touches `router.ex` first commits a file that may already contain another
slice's in-flight lines. That is accepted: no work is lost, the other slice's own
commit simply becomes a no-op for that file. History attribution is the cost.

After convergence, commit the repairs separately:

```
git add <convergence paths>
git commit -m "Converge shared registrations for <spec>"
```

### Preflight

Run before delegating anything, and report the result to the first delegation so
agents do not rediscover it independently:

- `git status --short` — leftovers from an interrupted previous run
- `mix compile --warnings-as-errors`
- `esdm lint`
- the spec's `broken_links` from parse

Leftover half-wired operations are the single most common cause of a failed
review here. Detect them in seconds at the start, not in a review cycle at the
end.

### Gates Are Builder-Run

The builder asserts deterministic checks directly, between delegations — never
through a subagent, and never re-asserted by the reviewer:

- `mix compile --force --warnings-as-errors`
- `MIX_ENV=test mix compile --warnings-as-errors`
- `mix format --check-formatted`
- `SportipediaWeb.System.ApiSpec.spec()` builds without raising
- `mix sp.gen <element> <name> --check` for every generated citizen
- the scoped test suite

A failing gate returns to the owning subagent with the raw command output — no
review cycle needed to discover a broken build.

### Convergence

After all slices commit:

1. Re-run `mix sp.gen` for every operation in the batch. Append-only + idempotent
   means this re-adds any registration unit lost to a concurrent write.
2. `sp.gen … --check` on each — a clean report proves convergence. Anything still
   `Outdated` must be an *authorized* deviation from the plan, never unexplained.
3. Compile, format, `ApiSpec.spec()`.
4. Full test suite, serially, unpartitioned.
5. Commit the repair.

### Question Handling

`QUESTION:` from any subagent is an escape hatch, not a designed path. Route it to
the product-specialist with the spec path, take the answer, and resume the asking
agent with it. Maximum one round-trip per slice.

**Domain-model gaps are different.** A `MODEL GAP:` from the architect or reviewer
(a read-model field no event produces, an actor mismatch) goes to the
product-specialist as a model correction, and the affected slice is rebuilt after
the model is fixed. Do not let an implementer paper over a model gap.

### Error Handling

- Gate failure → return output to the owning agent, one retry.
- Review fails after 3 attempts → commit the slice as-is with its file list and
  continue.
- Subagent session dies → re-spawn. Safe because generators are idempotent.
- Whole-slice failure → report it; the other slices' commits stand.

After the loop, report:

```
Build complete for {spec_path}:
  ✓ apparatus   (5 operations)  commit a1b2c3
  ✓ instrument  (5 operations)  commit d4e5f6
  ✗ position    (2 of 5)        review failed after 3 attempts, commit 789abc
```

### Precondition

The ESDM domain model files referenced in the spec's `## Domain Model` section must
already exist and be populated. Domain modelling is assumed complete before this
recipe runs.
