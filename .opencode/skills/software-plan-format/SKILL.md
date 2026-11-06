---
name: software-plan-format
description: Defines the format for a software design plan artifact passed between agents.
---

# Software Plan Format

## Overview

A software plan is a design artifact that carries **the decisions the generators
cannot make** for a domain slice. It is produced by the Software Architect and
consumed by the Backend Engineer. It records cross-boundary calls, invariant
realization, error semantics, actor mapping, model gaps and the slice boundary —
never layout.

Layout (module names, file paths, code shape) belongs to `mix sp.gen.*` and the
blueprints. Restating it duplicates a source of truth; restating it wrongly
creates a conflict the implementer must resolve. See
[plan-domain-feature](../plan-domain-feature/SKILL.md) for what to include.

All examples use the `catalog-apparatus` operation from the catalog subdomain.
See the [naming substitution](../../../docs/architecture/naming-substitution.md)
doc for placeholder conventions.

## Scope

A plan covers one of:

| `scope` | Contents |
|---|---|
| `feature` | every operation of one constituent (aggregate) |
| `operation` | exactly one command or query, domain actor |
| `endpoint` | exactly one command or query, web actor |

With `scope=feature`, one frontmatter block names the constituent and lists the
operations; the decision list is grouped by operation. Do not emit one plan per
operation.

## Structure

```
┌─────────────────────────────────┐
│  YAML Frontmatter               │ ← slice identity, operations, scope
├─────────────────────────────────┤
│  Decisions                      │ ← numbered, the plan's payload
├─────────────────────────────────┤
│  Model Gaps / Open Questions    │ ← if any
└─────────────────────────────────┘

┌─────────────────────────────────┐
│  Diagrams (OPTIONAL)            │ ← only for non-obvious flow
└─────────────────────────────────┘
```

---

## 1. YAML Frontmatter

```yaml
---
scope: feature
subdomain: catalog
composite: equipment
constituent: apparatus
operations: [catalog-apparatus, edit-apparatus, archive-apparatus, read-apparatus, list-apparatuses]
spec: docs/specs/catalog/equipment/spec-manage-apparatuses-19-05-2026.md
---
```

For `scope=operation` or `scope=endpoint`, replace `operations` with the single
`operation` and add `type: command | query`.

---

## 2. Decisions

Numbered list. Each entry names the operation it applies to and cites the source
it resolves (ESDM file, blueprint example, ADR). No preamble, no restatement of
the domain model.

```markdown
1. **catalog-apparatus — `equipment-exists`** reaches the other constituent
   through its public API, never `Repo` (internal-api.md). Existence only;
   archived equipment is accepted.
2. **all commands — `unique-slug`** per examples/unique-slug.md, plus a
   `unique_index` in the migration.
3. **archive-apparatus — actor mismatch:** model says `admin`, landed policy
   clause allows `user`. Must use `is_admin?/1`.
```

---

## 3. Model Gaps / Open Questions

Report, do not resolve. A field the read model requires that no event produces,
a constraint with no data to enforce it, a schema that cannot represent a legal
state. Prefix each with `MODEL GAP:`; ambiguity needing a business answer with
`QUESTION:`.

---

## 4. Diagrams (Optional)

Include a diagram only when the flow is genuinely non-obvious: a cross-boundary
call, a process manager, a multi-aggregate read. For a plain command or query the
sequence is already known and a diagram is padding.

### Stereotypes

| Stereotype | Applies to |
|---|---|
| `<<Command>>` | Command struct |
| `<<CommandHandler>>` | Handler module |
| `<<Aggregate>>` | Aggregate with `apply/2` |
| `<<Event>>` | Event struct |
| `<<Projector>>` | Projection module |
| `<<ReadModel>>` | Ecto read model |
| `<<Policy>>` | Authorization policy |
| `<<PublicAPI>>` | Public API entry point |
| `<<Controller>>` | Phoenix controller |
| `<<View>>` | JSONAPI view |
| `<<Query>>` | Ecto query |
| `<<InternalAPI>>` | Internal API |
| `<<Validator>>` | Custom Vex validator |

### Arrow Semantics

| Arrow | Meaning |
|---|---|
| `A --> B` | A dispatches to / calls / handles / evolves / projects / guards B |

### Sequence Diagram Rules

- Use `->>+` for calls and `-->>-` for returns (activation/deactivation).
- Label arrows with the function call or message.
- Show the authorization check as early as possible.
- For commands: Controller → API → Policy → Command → Handler → Aggregate, then
  the async projection phase separately.
- For queries: Controller → API → Policy → Internal API → Query → ReadModel.
- Name participants by role, not by file path.

---

## Constraints

- **Never restate layout.** No module table, no file paths, no generator order.
- **Never copy an ESDM schema** into the plan — reference the file.
- **Only the named slice.** No sibling operations, no other actors.
- **Docs-first.** Derive decisions from documentation. Never read implementation
  code for patterns.
- **Short.** A plan that a generator could have produced is not a plan.
