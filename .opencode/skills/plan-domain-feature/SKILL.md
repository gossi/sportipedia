---
name: plan-domain-feature
description: Plan a domain feature, one operation, or one endpoint in the Sportipedia domain — decisions only, never layout.
---

# Plan Domain Feature

## Overview

Produce the software plan for a CQRS/ES slice in the Sportipedia domain, using
only the scope you were given. The plan carries **the decisions the generators
cannot make** and nothing else.

The operation(s) are defined in the
[Domain Model](../../../docs/domain-model/README.md).

## Scope Parameter

The caller passes `scope`. It selects the slice boundary and the plan volume:

| `scope` | Covers | Expected size |
|---|---|---|
| `feature` | every operation of one constituent (aggregate), domain actor **and** web actor | one plan, all operations |
| `operation` | exactly one command or query, domain actor only | ~150 words |
| `endpoint` | exactly one command or query, web actor only | ~100 words |

With `scope=feature`, cover each listed operation once. Do not split into
per-operation sections — the implementer is one agent that loads the shared
scaffold once.

## Before You Start — Mandatory Checklist

Answer these questions BEFORE writing the plan. If any answer is "no" or
"unsure", STOP and ask.

- [ ] Do I know exactly which slice I'm planning, and its scope?
- [ ] Do I have the domain model files for every operation in scope?
- [ ] Am I planning ONLY the named slice? (no sibling operations unless listed)
- [ ] Do I have everything I need from documentation? (no code exploration required)

## Context for Executing the Skill

- [Respect Code Access Policy](../../code-access-policy.md) — **HARD CONSTRAINT**:
  Reading implementation code for patterns or reference is a task failure, not a
  warning. If violated: STOP, announce the violation, discard all knowledge from
  that code, and restart from documentation.
- This skill counts as documentation — it is sufficient for planning
- Also load the [software-plan-format](../software-plan-format/SKILL.md) skill —
  it defines the plan artifact's shape.
- DO NOT run discovery, DO NOT explore code

> ![CAUTION]
> Strictly forbidden: Reading code/Exploring code!
> NEVER!!! read code for reference implementation or check existing implementations.
> Failure Criteria: Reading Code, stop immediately!

If you read code: Admit your failure and stop!

## What NOT To Plan

The generators (`mix sp.gen.*`) and the
[blueprints](../../../docs/architecture/blueprints/README.md) own these. Stating
them again is waste, and stating them wrong is worse than silent — the
implementer will follow the generator over your plan.

- **Module names and namespaces.** Derived from
  [naming-substitution](../../../docs/architecture/naming-substitution.md) plus
  the blueprint templates.
- **File paths and directory layout.** "Roles, not paths: file layout belongs to
  the generators." Never derive a path yourself.
- **The generator invocation order.** The implementer runs them.
- **Code shape, function signatures, struct fields, changeset names.** The
  blueprints prescribe these.
- **Restating the ESDM data schemas.** The command and event YAML files are the
  source of truth; reference them, do not copy them.
- **Mermaid class diagrams of the standard sequence.** For a plain command or
  query the sequence is already known. Omit it.

## What TO Plan

Only what spgen cannot infer from the ESDM files. For each item, name the
operation it applies to.

1. **Cross-boundary calls** — a rule that must reach another composite or
   constituent. Say which boundary is crossed and **which public API** to go
   through. Internal APIs and `Repo` never cross a constituent boundary.
2. **Invariant realization** — for each aggregate invariant and each command
   constraint: which pattern applies, and any wiring the generator cannot get
   right (e.g. two `by:` pairs that Vex would overwrite on the same field).
   Cite the blueprint example by path when one exists.
3. **Error atom and HTTP status** — the atom each rule returns, and the status
   it renders to. Check `Sportipedia.Support.ErrorClassifier` semantics: some
   raw atoms are intercepted and re-routed, so the obvious atom may be
   unusable. If a rule needs a distinct status, say so explicitly.
4. **Actor mapping** — command actors to policy clauses. Flag any actor mismatch
   you find between the model and the spec (e.g. the model says `admin` but a
   landed clause allows `user`). Admin-only actors need `is_admin?/1`.
5. **Domain-model gaps** — a read-model field no event payload produces, a
   constraint with no data to enforce it, a missing optional/required marker.
   Report these as `MODEL GAP:` entries. They are the product-specialist's to
   fix, not the implementer's.
6. **Migration content** — the table, its prefix, indexes and constraints, when
   a unique index must back an invariant. Migrations are never generated.
7. **Left to operator** — anything the generator scaffolds but cannot complete
   (handler bodies, scaffold validators, TODO moduledocs).
8. **Out of scope** — explicitly, what must NOT land in this slice. This is the
   guard against half-wired sibling operations breaking the build.

## Process

1. Read the spec file (path given by the caller) for business intent, actors,
   and the QA scenarios.
2. Read the ESDM files for every operation in scope, plus the aggregate and the
   read model.
3. Consult the architecture docs and blueprints for the patterns the rules map
   onto.
4. Work through the eight "What TO Plan" items. Skip any that a blueprint
   example already settles; only flag it if the example is missing.
5. Verify against architecture guidelines, then present.

## Step: Present the Result

Follow the `software-plan-format` skill for the shape. Keep it short: frontmatter,
the numbered decision list, and a `MODEL GAP` / `OPEN QUESTION` section if any.
Diagrams only when a flow is genuinely non-obvious (cross-boundary calls,
process managers, multi-aggregate reads).

If business logic is ambiguous, output `QUESTION: <your question>` and stop.

## Verification — Before Declaring Done

If any answer is "no", you have padding or scope creep:

- [ ] Did I avoid naming any file path or module name?
- [ ] Did I avoid copying an ESDM schema into the plan?
- [ ] Is every line a decision the generators cannot make?
- [ ] Did I state the out-of-scope boundary for this slice?
- [ ] Did I report domain-model gaps instead of papering over them?
- [ ] Did I read any implementation file? (should be: no)
