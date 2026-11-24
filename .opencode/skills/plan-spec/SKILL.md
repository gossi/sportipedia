---
name: plan-spec
description: Turn what a spec states into the list of work it implies, split into generated work and manual work.
---

# Plan Spec

## Overview

Takes the result of [parse-spec](../parse-spec/SKILL.md) and answers one question:
**what work does this document imply**. The answer is `changes`, one item per piece of
work, tagged `generated` or `manual`.

**Executed by the software-architect** in the `plan` step of the
[spec recipe](../../recipes/spec.recipe.md). Load [use-sparch](../use-sparch/SKILL.md)
first: it says how to ask the tool anything.

## Words that carry the design

- **generated work** — a generator covers it. If a generator exists for a thing, that
  generator is used. Never write by hand what a generator owns.
- **manual work** — no generator covers it. The authority for this is not opinion, it
  is the **manual page**: `sparch man <generator>` states, per generator, what it
  writes and what it lists under "Left to you".
- **read-only report** — `mix sp.gen.<suite|generator> <element> --diff`. It writes
  nothing and says how each generated unit stands against the model.
- **the frontend is generated work throughout.** No manual item belongs to it, and it
  needs no state report, because the suite is re-run for every read model in scope and
  its output is what stands.

## Two rules that bound this skill

- **Read no implementation file.** Generated truth comes from the read-only report,
  which asks the tree without reading it by hand. Whether a piece of manual work
  already exists is unknown here, and `implement` is the one that finds out.
- **Emit no paths, module names, or ordered generator calls.** `sparch arch name` and
  `sparch arch location` answer the first two, and the suite carries the order. A plan
  that restates them contradicts the tree it describes.

## Steps

### 1. Take the parse result

Work from `domain_model`, `requirements`, `non_requirements`, `qa_scenarios`,
`tradeoffs`, `frontmatter.scope`, `label_address_mismatches` and `broken_links`.

### 2. Settle which generators are in play

Read `sparch capabilities` once. It lists every generator with the element kinds it
declares, per language, and the suites that group them. For each distinct kind in the
spec's domain model entries, the generator set is the ones declaring that kind, per
side that `scope` names. Take the set from that output, not from memory: a projector is
reached through the element's events, and a schema through several kinds, which is
exactly the kind of detail a list gets wrong.

### 3. Ask each manual page what it refuses

For every generator from step 2, read `sparch man <generator>`. A page that has a
"Left to you" section names the artifacts it declines, and that is manual work:
migrations with their unique index, custom changesets, shared validator bodies,
completion slots, uncovered test cases. A page without that section leaves nothing, so
do not invent work for it. The manuals are the only source for this kind of item.

### 4. Ask the tool how the generated backend units stand

Run `mix sp.gen.feature <aggregate> --diff` for each aggregate the spec names. Record
the state it gives, per unit: `added`, `changed`, `removed`, `deferred`, `blocked`, or
in sync. Attach that state to the generated items. An element the spec calls `Modified`
whose report is in sync yields no work, and that is a clean answer, not a defect.

For the frontend, `scope` decides whether it is in play, and each read model in scope
gets one generated item whose action is to re-run `pnpm spgen feature <read-model>`.
No state question is asked of it.

### 5. Read the requirements sections for what the model cannot express

Each bullet in `functional`, `technical`, `integration` and `user_experience` that
describes behavior no generator produces becomes a manual item, with the section and
bullet as its origin. Each entry in `qa_scenarios` becomes a manual test item naming
the element and scenario it must cover. A `Referenced` entry adds no work; it states a
dependency, and the item that checks it exists says so.

### 6. Handle the Removed bucket

Generators add and never remove. For every `removed` entry, the generated units that
element owns become manual items of kind `delete`, stating what a clean read-only
report will not prove: the field or clause is gone from the model, so its code must be
found and deleted by hand.

### 7. Stop on a disagreement between spec and model

Report and stop, without going further, when:

- a named element has no ESDM file behind its link, or its link resolves to a
  different element than its label
- the read-only report says `blocked` for an element the spec treats as settled
- `scope` names a side whose elements the spec does not list, or the spec lists an
  element whose side `scope` omits

Each is stated as one finding naming the document section and the element. These are
defects in the spec or in the model, and the product-specialist owns them. Do not
choose between the two, and do not fill the gap from code.

### 8. Return the result

```json
{
  "changes": [
    { "work": "generated", "element": "command.catalog-apparatus",
      "generator": "command", "state": "added", "origin": "## Domain Model (New)" },
    { "work": "manual", "kind": "write",
      "origin": "sparch man read_model: Left to you (migration and unique index)" },
    { "work": "manual", "kind": "write",
      "origin": "## Quality Assurance → catalog-apparatus-duplicate-slug" },
    { "work": "manual", "kind": "delete",
      "origin": "## Domain Model (Removed) → read-model.apparatus" }
  ],
  "excluded": [ "## Non-requirements → …" ],
  "findings": [ "…disagreements from step 7, empty when the plan proceeds" ],
  "sides": ["backend"],
  "elements": ["apparatus"]
}
```

Every item carries the section or manual page it came from, because `implement` and
`review` need to find the sentence again, not a paraphrase of it.

## Verification

- [ ] Did I use `sparch capabilities` and `sparch man` rather than my own memory?
- [ ] Is every item either generated work with a generator named, or manual work with
      a "Left to you" or spec section as its origin?
- [ ] Did I avoid inventing manual work that a generator actually covers?
- [ ] Did I avoid claiming any manual artifact exists or is missing?
- [ ] Did I name no file path, no module, and no ordered generator call?
- [ ] Did I read any implementation file? (should be: no)
- [ ] Did every `removed` entry become delete work?
- [ ] Are all step 7 disagreements reported instead of resolved?
