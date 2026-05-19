# TODO: Archive guard for apparatus (no-archive-when-in-use)

**Spec:** [spec-manage-apparatuses-19-05-2026.md](../catalog/equipment/spec-manage-apparatuses-19-05-2026.md)  
**Domain invariant:** `no-archive-when-in-use` on the `apparatus` aggregate  
**Status:** 🔴 Not implementable in current iteration

## What needs to be done

Implement a cross-aggregate guard on `archive-apparatus`: before archiving, query the sport read model to verify that no sport currently references this apparatus via `use-apparatus`. If any sport does, reject the command with an error indicating the apparatus is in use.

## Why it cannot be implemented now

The guard depends on the `use-apparatus` / `withdraw-apparatus` commands (on the `sport` aggregate) being implemented first. These commands are responsible for:
- Associating an apparatus with a sport (`use-apparatus`), which writes the apparatus ID into the sport's equipment list
- Dissociating an apparatus from a sport (`withdraw-apparatus`), which removes the apparatus ID from the sport's equipment list

Without these commands, there is no mechanism for an apparatus to ever become associated with a sport. The sport read model will never contain apparatus references, making the guard query always return zero results — dead code.

## Prerequisites

1. Implementation of `use-apparatus` and `withdraw-apparatus` on the `sport` aggregate
2. A reliable query on the sport read model to find sports by referenced apparatus ID
3. Integration of that query into the `archive-apparatus` command handler or middleware pipeline

## When this is resolved

- The domain model invariant `no-archive-when-in-use` becomes enforceable
- The QA scenario "Archive an Apparatus When in Use by a Sport" in the spec becomes testable
- The unconditional archive behavior is replaced with the guarded one

## Cross-references

- [Aggregate: apparatus](../../domain-model/catalog/equipment/aggregate.apparatus.esdm.yaml) — defines the invariant
- [Command: use-apparatus](../../domain-model/catalog/sport/command.use-apparatus.esdm.yaml) — prerequisite (out of scope)
- [Command: withdraw-apparatus](../../domain-model/catalog/sport/command.withdraw-apparatus.esdm.yaml) — prerequisite (out of scope)
- [Read Model: sport](../../domain-model/catalog/sport/read-model.sport.esdm.yaml) — the read model to query
