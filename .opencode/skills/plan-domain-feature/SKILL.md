---
name: plan-domain-feature
description: Preflight the spec and domain model, translate them into technical design, and emit the generator call sequence with per-operation work packages.
---

# Plan Domain Feature

## Overview

Turn a spec and its ESDM domain model into a technical design the generators can
execute: the ordered `mix sp.gen.*` calls, what each one leaves incomplete, and
the decisions no generator can make.

The operation(s) are defined in the
[Domain Model](../../../docs/domain-model/README.md).

**Executor: software-architect.** Load `parse-spec` first — it lints the model and
extracts the operation list and grouping. This skill is the design that follows.

## Scope Parameter

| `scope` | Covers |
|---|---|
| `feature` | every operation of one aggregate — the whole spec |
| `operation` | exactly one command or query, domain actor |
| `endpoint` | exactly one command or query, web actor |

With `scope=feature`, cover each listed operation once. The implementer is one
agent per work package; do not split into per-operation plans.

## Before You Start — Mandatory Checklist

If any answer is "no" or "unsure", STOP and ask.

- [ ] Do I know exactly which slice I'm planning, and its scope?
- [ ] Have I read every ESDM file for every operation in scope — the commands,
      the events, the aggregate, the read model, and the queries?
- [ ] Did `esdm lint` pass for this constituent, or did I raise a `MODEL GAP`?
- [ ] Am I planning ONLY the named slice?
- [ ] Do I have everything I need from documentation, with no code exploration?

## Context for Executing the Skill

- [Respect Code Access Policy](../../code-access-policy.md). **Reading
  implementation code for patterns or reference is a task failure** in design
  scope: patterns come from the blueprints and the architecture docs. When you
  review code, that restriction is lifted — this is the design step.
- Also load `software-plan-format` for the artifact shape.
- DO NOT run discovery, DO NOT explore code.
- If a template seems incomplete, that is a documentation gap — report it, do
  not fill it from code.

## Step 1: Preflight

Compare the spec's stated requirements against the model, and report any place
they disagree. The spec is a product document and the model is the technical
translation — a difference between them is a defect in one of the two, and the
design step is the cheapest moment to find it.

Check each operation for:

1. **Actors** — the command's `actors:` list against what the spec says may run
   it. A `user` in the model and `admin` in the spec is a contradiction, and the
   policy guard follows the model.
2. **Invariants** — every invariant the spec names exists in the aggregate, and
   every aggregate invariant appears in the spec.
3. **Command data vs spec fields** — a field the spec requires the command to
   accept but the model does not declare, or the reverse.
4. **Read model vs events** — a field in the read model no event can populate, or
   an event payload field with no home in the read model.
5. **Observable contract** — what the spec says a client sees after an operation
   (found, not found, removed, listed) must follow from the model's semantics.

Each disagreement: `MODEL GAP: <file> — <what and why>` and stop. The
product-specialist resolves the model; the design does not proceed past it.

Also report every relative link in the spec that fails to resolve. Broken links
silently degrade traceability — the reader gets no error, just a missing document.

If business logic is ambiguous, output `QUESTION: <question>` and stop.

## Step 2: Technical Translation

Translate the domain statements into the technical decisions the generators
cannot make. For each operation, state:

- **The projector effect** each event produces — insert, update or delete —
  derived from what the domain fact means. A domain term and its mechanism may
  differ; that is correct design, not a mismatch.
- **The realization of every invariant and command constraint** — which pattern,
  and any wiring the generator cannot get right (e.g. Vex keys validations per
  field, so two `validates` calls naming the same field replace each other).
  Cite the blueprint example path when one exists.
- **The migration content** — table, prefix, nullability, and the index that
  backs each unique invariant. Migrations are never generated.
- **Endpoint scoping** for web scope: request and response schemas, view fields,
  and the route verb (commands are POST).

## Step 3: Generator Call Sequence

Emit the ordered list of `mix sp.gen.*` invocations, with `--template` and any
`--composite` / `--constituent` flags the generator requires.

**List calls, never paths or module names.** `mix sp.gen.command catalog-position
--template create` is a step; `operations/catalog_position/command.ex` is not —
layout belongs to the generators, and restating it produces a plan that
contradicts the tree it is supposed to produce.

One element per call, in dependency order: read model → event → aggregate →
command or query → command handler → projector → policy → public API → view →
schema → controller → Bruno. Shared citizens (read model, aggregate, view,
schemas) appear once, on the first operation that needs them.

## Step 4: Work Packages

Per operation, what generation cannot complete. The implement workers get exactly
these and nothing else, so be explicit:

- handler bodies, scaffolded validators, `@moduledoc`/`@doc` TODOs
- manual tests the generators do not cover (invariant cases, handler field
  mapping, projector idempotency, public-API success cases, endpoint error
  statuses)
- the migration, when this is the first operation of the aggregate
- shared-file units: name which operation owns each shared validator body, so two
  workers do not both fill one file

## Step 5: Authorized-Deviation Register and Boundary

Declare, up front, any place the implementation must diverge from generator or
blueprint default — for example one scaffolded reference validator split into two
field-specific validators, or a validator pair deliberately moved to another
field. The final `--check` pass classifies each divergence against this register;
without it, intentional deviations are indistinguishable from lost registrations
and get "repaired" back into the wrong shape.

State the boundary too: which operations are **not** in this slice. Half-wired
siblings are a build breaker, not padding — an action for an operation with no
command behind it fails `--warnings-as-errors`, and a policy clause defaulting to
`is_user?` for an admin-only rule is a security hole that slice inherits silently.

## Step 6: Present the Result

Follow `software-plan-format`. The artifact is: scope and operation list, preflight
findings, the technical translation, the call sequence, the work packages, the
deviation register, and the out-of-scope boundary.

No module table. No file paths. No diagrams of a standard write or read sequence —
include one only when the flow is genuinely non-obvious (cross-boundary calls,
process managers, multi-aggregate reads).

## Verification — Before Declaring Done

If any answer is "no", you have padding, scope creep, or an unverified claim:

- [ ] Did I run `esdm lint` before designing?
- [ ] Did I preflight spec against model, and raise every disagreement as a
      `MODEL GAP`?
- [ ] Did I avoid naming any file path or module name?
- [ ] Did I avoid copying an ESDM schema into the design?
- [ ] Is every error-status claim either cited or marked `UNVERIFIED`?
- [ ] Did I state the out-of-scope boundary and the deviation register?
- [ ] Did I name the single owner of each shared validator body?
- [ ] Did I read any implementation file? (should be: no)
