# TODO: Archive guard for apparatus (no-archive-when-in-use)

**Spec:** [spec-manage-apparatuses-19-05-2026.md](../catalog/equipment/spec-manage-apparatuses-19-05-2026.md)  
**Domain invariant:** `no-archive-when-in-use` on the `apparatus` aggregate  
**Status:** 🟠 Partially implementable — the **position** guard is ready once the athlete position slice lands; the **sport** guard stays blocked (see below)

## What needs to be done

Extend the cross-aggregate guard on `archive-apparatus` so an apparatus cannot be archived while **anything references it**. There are two referrers, with two different readiness states:

### Referenced by a position (implementable now)

A position references an apparatus through its `apparatusId`
([command.catalog-position](../../domain-model/catalog/athlete/command.catalog-position.esdm.yaml)).
Before archiving, query the position read model
([read-model.position](../../domain-model/catalog/athlete/read-model.position.esdm.yaml))
for any position carrying this apparatus's `id`. If one exists, reject
`archive-apparatus` with an error indicating the apparatus is in use by a
position.

**Why this matters to the position slice:** the position read model derives its
globally unique `slug` from the referencing apparatus' current slug
(`<apparatus-slug>/<position-slug>`). Archiving an apparatus a position still
names would leave that position bound to equipment that can no longer be
maintained — and, under a "no cascade" policy, would strand the position's slug
derivation. Forbidding the archive while a position references the apparatus
keeps every bound position's `slug` resolvable for the whole life of the
reference. This is the rule the athlete position spec relies on:
[spec-position-05-11-2026.md](../catalog/athlete/spec-position-05-11-2026.md).

### Referenced by a sport (not implementable now)

Query the sport read model to verify no sport references this apparatus via
`use-apparatus`. If any sport does, reject the command. This half depends on the
`use-apparatus` / `withdraw-apparatus` commands (on the `sport` aggregate) being
implemented first. These commands are responsible for:
- Associating an apparatus with a sport (`use-apparatus`), which writes the apparatus ID into the sport's equipment list
- Dissociating an apparatus from a sport (`withdraw-apparatus`), which removes the apparatus ID from the sport's equipment list

Without these commands, there is no mechanism for an apparatus to ever become associated with a sport. The sport read model will never contain apparatus references, making that part of the guard dead code.

## Prerequisites

1. **Position guard:** implementation of the athlete position slice (catalog/edit/archive) so the position read model exists to query by `apparatusId`.
2. **Sport guard:** implementation of `use-apparatus` and `withdraw-apparatus` on the `sport` aggregate (out of scope).
3. A query on the position read model to find positions by referenced `apparatusId`.
4. A query on the sport read model to find sports by referenced apparatus ID (once sports reference apparatus).
5. Integration of the guard into the `archive-apparatus` command handler or middleware pipeline.

## When this is resolved

- The domain model invariant `no-archive-when-in-use` becomes enforceable against **both** referrers
- The QA scenario "Archive an Apparatus When in Use by a Sport" in the spec becomes testable, and a position-in-use scenario becomes testable once positions are built
- The unconditional archive behavior is replaced with the guarded one

## Cross-references

- [Aggregate: apparatus](../../domain-model/catalog/equipment/aggregate.apparatus.esdm.yaml) — defines the invariant
- [Aggregate: position](../../domain-model/catalog/athlete/aggregate.position.esdm.yaml) — the `unique-slug-by-equipment` invariant that depends on this guard
- [Read Model: position](../../domain-model/catalog/athlete/read-model.position.esdm.yaml) — the projection to query for `apparatusId` references
- [Command: use-apparatus](../../domain-model/catalog/sport/command.use-apparatus.esdm.yaml) — sport-reference prerequisite (out of scope)
- [Command: withdraw-apparatus](../../domain-model/catalog/sport/command.withdraw-apparatus.esdm.yaml) — sport-reference prerequisite (out of scope)
- [Read Model: sport](../../domain-model/catalog/sport/read-model.sport.esdm.yaml) — the read model to query for sport references
