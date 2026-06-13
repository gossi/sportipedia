# TODO: Archive guard for instrument (no-archive-when-in-use)

**Spec:** [spec-manage-instruments-13-06-2026.md](../catalog/equipment/spec-manage-instruments-13-06-2026.md)  
**Domain invariant:** `no-archive-when-in-use` on the `instrument` aggregate  
**Status:** 🔴 Not implementable in current iteration

## What needs to be done

Implement a cross-aggregate guard on `archive-instrument`: before archiving, query the sport read model to verify that no sport currently references this instrument via `use-instrument`. If any sport does, reject the command with an error indicating the instrument is in use.

## Why it cannot be implemented now

The guard depends on the `use-instrument` / `withdraw-instrument` commands (on the `sport` aggregate) being implemented first. These commands are responsible for:
- Associating an instrument with a sport (`use-instrument`), which writes the instrument ID into the sport's equipment list
- Dissociating an instrument from a sport (`withdraw-instrument`), which removes the instrument ID from the sport's equipment list

Without these commands, there is no mechanism for an instrument to ever become associated with a sport. The sport read model will never contain instrument references, making the guard query always return zero results — dead code.

## Prerequisites

1. Implementation of `use-instrument` and `withdraw-instrument` on the `sport` aggregate
2. A reliable query on the sport read model to find sports by referenced instrument ID
3. Integration of that query into the `archive-instrument` command handler or middleware pipeline

## When this is resolved

- The domain model invariant `no-archive-when-in-use` becomes enforceable
- The QA scenario "Archive an Instrument When in Use by a Sport" in the spec becomes testable
- The unconditional archive behavior is replaced with the guarded one

## Cross-references

- [Aggregate: instrument](../../domain-model/catalog/equipment/aggregate.instrument.esdm.yaml) — defines the invariant
- [Command: use-instrument](../../domain-model/catalog/sport/command.use-instrument.esdm.yaml) — prerequisite (out of scope)
- [Command: withdraw-instrument](../../domain-model/catalog/sport/command.withdraw-instrument.esdm.yaml) — prerequisite (out of scope)
- [Read Model: sport](../../domain-model/catalog/sport/read-model.sport.esdm.yaml) — the read model to query
