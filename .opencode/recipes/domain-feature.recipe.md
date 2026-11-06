---
$schema: ./recipe.schema.yaml
name: domain-feature
description: Build a complete feature slice — every operation of one aggregate, domain and web actors together, in a single implementer
parameters:
  spec_path:
    type: string
    required: true
    description: "Path to the spec markdown file governing this feature"
  feature:
    type: string
    required: true
    description: "Constituent / aggregate name — the slice identity, e.g. 'position'"
  composite:
    type: string
    required: false
    description: "Composite the constituent lives in, e.g. 'athlete'"
  operations:
    type: array
    required: true
    description: "Every operation of this aggregate, in build order"
  partition:
    type: string
    required: false
    description: "MIX_TEST_PARTITION value for this slice. Defaults to the feature name."
steps:
  - id: plan
    agent: software-architect
    skill: plan-domain-feature
    with:
      scope: feature
      feature: ${parameters.feature}
      composite: ${parameters.composite}
      operations: ${parameters.operations}
      spec_path: ${parameters.spec_path}

  - id: implement
    agent: backend-engineer
    skills:
      - tdd
      - use-blueprints
    with:
      feature: ${parameters.feature}
      composite: ${parameters.composite}
      operations: ${parameters.operations}
      plan: ${steps.plan.result}
      spec_path: ${parameters.spec_path}
      partition: ${parameters.partition}

  - id: gates
    builder: gates
    with: { feature: "${parameters.feature}" }

  - id: review-loop
    loop:
      max: 3
      steps:
        - agent: reviewer
          with:
            feature: ${parameters.feature}
            operations: ${parameters.operations}
            plan: ${steps.plan.result}
            gates: ${steps.gates.result}
            spec_path: ${parameters.spec_path}
          exit-when: ${result.review.status} == "pass"
        - agent: backend-engineer
          skills:
            - tdd
            - use-blueprints
          with:
            feature: ${parameters.feature}
            operations: ${parameters.operations}
            review: ${result}
            spec_path: ${parameters.spec_path}
            partition: ${parameters.partition}

  - id: commit
    builder: commit-feature
    with:
      feature: ${parameters.feature}
      files: ${steps.implement.result.files}
approval: auto
---

# Domain Feature Recipe

Build one **feature slice**: every operation of a single aggregate, domain actor
and web actor included.

## Why One Slice Per Aggregate, Not One Call Per Operation

Operations on the same aggregate share `public_api.ex`, `policy.ex`,
`<object>_controller.ex`, `aggregate.ex`, `projector.ex`, `read_model.ex`, the
JSON:API view and the router scope. Splitting them across agents means concurrent
writes to the same files. Built by one agent, the shared scaffold — the aggregate,
the read model, the migration, the view, the response schemas, the registrations —
is created once by the first operation and extended by the rest, and the plan is
read once instead of N times.

Five operations under this recipe cost **3–4 subagent calls** instead of ~45.

## Structure

1. **Plan** — one architect call for the whole slice. The plan carries decisions
   only; no module table, no file paths, no generator order.
2. **Implement** — one engineer builds all operations, test-first, looping the
   generators internally.
3. **Gates** *(builder)* — compile, format, `ApiSpec.spec()`, `--check`, scoped
   tests. Deterministic, so the reviewer is never asked to rediscover a broken
   build.
4. **Review** — up to 3 attempts, exit on `pass`.
5. **Commit** *(builder)* — the slice's file list only.

## The Implementer's Inner Loop

For each operation, in the order the plan and `parse-spec` give:

```
mix sp.gen.read_model <aggregate>          # first operation only
mix sp.gen.event <event>
mix sp.gen.aggregate <aggregate>            # first operation only
mix sp.gen.command <operation>              # or sp.gen.query
mix sp.gen.command_handler <operation>
mix sp.gen.projector <event>
mix sp.gen.policy <operation>
mix sp.gen.public_api <operation>
mix sp.gen.view <aggregate>                 # first operation only
mix sp.gen.schema <aggregate>               # read model  → response schemas
mix sp.gen.schema <operation>               # command     → request schema
mix sp.gen.controller <operation>           # action + web route + endpoint test
mix sp.gen.bruno <operation>
```

Then the operator-residual work the plan names: handler bodies, scaffold
validators, migration, `@moduledoc` TODOs, and the manual tests for cases the
generators do not cover.

Generators are append-only and idempotent — re-running them is the repair path
for lost registrations, so never fight a merge by hand-editing a registry file.

## Slice Boundary

The spec describes the whole feature; a slice contains **only** the operations it
was given. The implementer must not pre-wire siblings: no controller action,
router entry, policy clause, public-API function or projector clause for an
operation outside the list. Half-wired siblings produce undefined-function
warnings, break `--warnings-as-errors`, and make `ApiSpec.spec()` raise. When the
generators append such units anyway, delete them and note the deletion as an
authorized deviation.

A policy clause for an operation outside the slice is a security problem, not just
a build problem: an archive clause defaulting to `is_user? -> :ok` pre-wires a
bypass of an admin-only rule that the later slice inherits silently.

## FILES Contract

The implementer and every fixer end their response with:

```
FILES:
  services/api/lib/sportipedia/catalog/athlete/position/public_api.ex
  services/api/lib/sportipedia_web/catalog/athlete/position/position_controller.ex
  services/api/lib/sportipedia_web/router.ex
  ...
```

The builder unions this with the paths from spgen's run report and commits exactly
that set. Subagents never run git.

## Handoff to the Reviewer

Give the reviewer: the plan, the raw gate output, the file list, and the slice
boundary. Do **not** ask it to re-run gates — it reviews naming, contract
boundaries, authorization against the ESDM actors, invariant coverage, spec QA
scenario coverage, and whether shared registrations survived.

One dimension gates cannot see, and the reviewer must own it: **does the advertised
API surface agree with what the pipeline actually accepts and emits?** A generated
sort whitelist naming a field the read model does not have, or a sparse-fieldset
enum publishing camelCase attributes that `JSONAPI.QueryParser` underscores before
matching, both pass compile, format and tests while the documented contract is
unusable — the first silently strips every `ORDER BY` from a paginated read, the
second answers 500 to a client that follows the schema. Assertions about an
advertised name must be traced to the schema module or library that consumes it.

## Deviation Discipline

When the implementer overrides the plan (a real case: the plan demanded HTTP 422
via the atom `:not_found`, but `ErrorClassifier` intercepts `:not_found` and
re-routes it to 404, so the atom had to become `:equipment_not_found`), it must
report the override. The builder then routes the settled rule back to the
documentation — a blueprint example or the spec — so the next slice inherits a
decision instead of relitigating it.

`MODEL GAP:` findings route to the product-specialist to fix the ESDM files, then
`esdm lint`. Do not let the implementer invent a payload to close a model gap.

### A deviation that leaves generator-active prose behind is not finished

Some model text is not description but **input to the generator**. A read model's
projection `rule:` prose selects the generated projector clause, so prose that does
not match the code being written silently re-derives the wrong clause on the next
run. Observed on the `position` aggregate: the rule text "Mark position as archived"
derived an update clause whose `get_changes/1` was empty — a permanent no-op — and
after the code was hand-corrected to a delete, that stale prose kept threatening to
undo the correction.

Rule: if you replace, delete or re-wire generator output, find the model text that
drove it and correct it in the same batch, using the effect vocabulary the generator
recognizes. If you cannot, say so explicitly rather than leaving a landmine for the
next run.

The reverse also holds: a deviation the model cannot express — a read-model field no
event ever populates, an address key the command does not declare — is a `MODEL GAP`
for the product-specialist, never a reason to invent code.

### Generators add; they never remove

`SpGen.Merge` is append-only by design, so **a deletion in the domain model does not
propagate to code**. Dropping a read-model field leaves the schema field, the migration
column, the published JSON:API attribute and the OpenAPI response entry all in place, and
re-running the generator will not clean them up. Model deletions therefore require an
explicit hand-deletion pass, and must be listed as such in the slice report.

Practical consequence for review: an `--check` report that comes back **in-sync** after a
model deletion is not evidence of convergence. Verify absence in the code itself.

## What Gets Built

Domain actor: public API function, command/query module, handler, events,
aggregate, projector, read model, policy, validators, internal API, migration.
Web actor: controller, router entry, JSON:API view, OpenAPI request and response
schemas, Bruno documentation. All tests.
