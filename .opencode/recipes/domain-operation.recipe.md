---
$schema: ./recipe.schema.yaml
name: domain-operation
description: Plan and implement the domain operation for exactly one command or query
parameters:
  operation:
    type: string
    required: true
    description: "The exact domain operation name (command or query)"
  spec_path:
    type: string
    required: false
    description: "Path to the governing spec, when one exists"
  partition:
    type: string
    required: false
    description: "MIX_TEST_PARTITION value. Defaults to the operation name."
steps:
  - id: plan
    agent: software-architect
    skill: plan-domain-feature
    with:
      scope: operation
      operation: ${parameters.operation}
      spec_path: ${parameters.spec_path}

  - id: implement
    agent: backend-engineer
    skills:
      - tdd
      - use-blueprints
    with:
      operation: ${parameters.operation}
      scope: operation
      plan: ${steps.plan.result}
      spec_path: ${parameters.spec_path}
      partition: ${parameters.partition}

  - id: gates
    builder: gates
    with: { operation: "${parameters.operation}" }

  - id: review-loop
    loop:
      max: 3
      steps:
        - agent: reviewer
          with:
            operation: ${parameters.operation}
            scope: operation
            plan: ${steps.plan.result}
            gates: ${steps.gates.result}
            spec_path: ${parameters.spec_path}
          exit-when: ${result.review.status} == "pass"
        - agent: backend-engineer
          skills:
            - tdd
            - use-blueprints
          with:
            operation: ${parameters.operation}
            scope: operation
            review: ${result}
            spec_path: ${parameters.spec_path}
            partition: ${parameters.partition}

  - id: commit
    builder: commit-feature
    with:
      feature: ${parameters.operation}
      files: ${steps.implement.result.files}
approval: auto
---

# Domain Operation Recipe

Plan and implement exactly ONE CQRS/ES domain operation.

Standalone entry point for a single operation or a repair. `domain-feature` no
longer composes this recipe — it inlines the same work across all of an
aggregate's operations — but this remains at your disposal, and it follows the
same rules.

## Structure

1. **Plan** — `plan-domain-feature` with `scope=operation`. Decisions only.
2. **Implement** — `tdd` + `use-blueprints`, test-first.
3. **Gates** *(builder)* — deterministic checks, run directly.
4. **Review** — up to 3 attempts, exit on `pass`.
5. **Commit** *(builder)* — the operation's file list only.

## What Gets Built

Public API function, command or query module, command handler, events, aggregate,
projector, read model, policy, validators and queries, internal API, migration,
all tests.

## Rules Inherited from the Feature Recipe

- **No layout in the plan.** Module names, file paths and the generator order
  belong to `mix sp.gen.*` and the blueprints. The plan is cross-boundary calls,
  invariant realization, error atoms and statuses, actor mapping, model gaps,
  migration content, and residuals.
- **Pass artifacts by reference.** Give subagents the spec path; never paste its
  contents into a prompt.
- **No `find-domain-operation` step.** The generators fail loudly on an unknown
  operation name, which is a cheaper existence check than a subagent call.
- **Slice boundary.** Domain actor only. No controller, view, schema, web route,
  endpoint test or Bruno file — that is `domain-endpoint`.
- **No pre-wired siblings.** Do not add clauses for operations outside the named
  one. Half-wired siblings break `--warnings-as-errors` and `ApiSpec.spec()`.
- **Generators are the repair path.** Append-only and idempotent — re-run rather
  than hand-merging a registry file.
- **FILES contract.** The implementer and every fixer end with a `FILES:` list;
  the builder unions it with spgen's reported paths and commits that set.
  Subagents never run git; `git add -A` is forbidden.
- **`MODEL GAP:` routing.** Report read-model fields no event produces, or actor
  mismatches between the ESDM and the spec, for the product-specialist to fix.
  Never close a model gap by inventing code.
- **Deviations go back into the docs.** An override that survives review becomes a
  blueprint or spec edit, so the next slice inherits the decision.

## When to Prefer This Over the Feature Recipe

Only when exactly one operation of an aggregate needs work — a repair, a missing
test, a changed invariant. For a fresh aggregate, use `domain-feature`: it loads
the shared scaffold once and reviews the slice as a whole, which is where
cross-operation contamination is visible.
