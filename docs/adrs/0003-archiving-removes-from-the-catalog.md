---
status: accepted
date: 2026-11-07
decision-makers: [thomas]
consulted: []
informed: []
---

# Archiving Removes from the Catalog

## Context and Problem Statement

The catalog's operations are named `archive-*` (`archive-apparatus`,
`archive-instrument`, `archive-position`). The name invites an "archived" state:
a flag on the read model, an aggregate state that rejects a second archive, an
`archivedAt` timestamp, queries that exclude archived rows, a possible
unarchive. The equipment constituents (apparatus, instrument) were built first
and settled the question there; the position spec states it as a tradeoff
([spec, Tradeoffs: Archive means delete](../specs/catalog/athlete/spec-position-05-11-2026.md#archive-means-delete)).

## Decision

**Archiving is a delete.** `archive-<domain object>` removes the object from the
catalog:

- The event (`<domain-object>-archived`) carries only the id.
- The projector deletes the read-model row (and no-ops when the row is already
  gone, keeping replay idempotent).
- The aggregate's `apply/2` for the event yields `nil` — there is no archived
  state to be in.
- The read model carries no flag and no `archivedAt` column; the migration
  carries none either. There is no "exclude archived" predicate anywhere,
  because there is nothing to exclude: the row is gone.
- Re-archiving answers `404`; the slug is immediately reusable; nothing offers
  an unarchive.

## Decision Drivers

1. **One rule across the catalog** — apparatus and instrument already delete on
   archive; a second convention for athlete/position would split the meaning of
   the same operation name across constituents.
2. **Nothing reads the archived state** — no filter, no counter, no unarchive
   endpoint exists; a flag nothing consults is dead data with a cost at every
   read.
3. **History is not lost** — the delete is complete in the projection, not in
   the event store: `<domain-object>-archived` remains in the stream as the
   audit trail (pinned by position's operation and endpoint tests).

## Consequences

- A reference into a deleted object dangles by design: positions keep references
  to archived equipment; the catalog does not cascade (the spec's other
  tradeoff). Existence checks read "exists" as "is in the catalog".
- Addressing a deleted object always answers `404` — never `410`, and never a
  second `204` for a re-archive.
- The operation name and its behavior disagree on the surface ("archive" sounds
  reversible); the domain-model README's Conventions section states the rule so
  code and model speak it the same way.

## References

- `docs/specs/catalog/athlete/spec-position-05-11-2026.md` — §Tradeoffs: "Archive means delete"
- `docs/domain-model/README.md` — §Conventions
- `docs/adrs/0001-authorization-at-controller-level.md` — the re-archive `404` flows through controller-level authorization unchanged
