---
title: Manage Instruments in the Backend
feature: manage-instruments
subdomain: catalog
composite: equipment
scope: backend
---

# Manage Instruments in the Backend

**Build the complete backend for the `instrument` aggregate — domain logic (CQRS/ES), JSON:API web endpoints, and API client requests — so that movable sports equipment (instruments) can be cataloged, edited, listed, read, and archived by the system.**

## Background

### Context

The Sportipedia catalog subdomain distinguishes two types of sports equipment:

- **Instruments** — movable equipment the athlete controls and moves around (e.g., a unicycle, skateboard, tennis racket). In sport science terms, an instrument is a _movendum_ the athlete controls (see Göhner). The domain model (ESDM yaml files) is fully defined in terms of aggregate, commands, events, and read model.
- **Apparatuses** — immovable equipment the athlete interacts with but never moves (e.g., a gymnastics beam, climbing wall, pommel horse). The `apparatus` aggregate serves as a proven, complete reference implementation following the project's CQRS/ES architecture (Commanded framework, Elixir/Phoenix).

The `instrument` aggregate is structurally analogous to `apparatus` in its domain model, making this a straightforward implementation that should follow the exact same patterns.

Currently, the system cannot manage instruments — they only exist as abstract ESDM definitions. This gap blocks any feature that depends on instrument data (e.g., associating instruments with skills or exercises, or displaying instrument information).

### Problem Statements

- Instruments cannot be cataloged — there is no backend code to accept and persist instrument data.
- Instruments cannot be queried — neither listing all instruments nor reading a single instrument by ID is possible.
- Instruments cannot be edited or archived — there is no way to update instrument metadata or remove unused ones.
- API consumers (frontend, admin tools, third-party integrations) have no endpoints to interact with instrument data.

## Domain Model

Used Domain Models:

- [Aggregate: instrument](../../../domain-model/catalog/equipment/aggregate.instrument.esdm.yaml): Root aggregate for movable sport equipment. Defines invariants `unique-slug` (slug must be unique) and `no-archive-when-in-use` (instrument can only be archived when no sport references it). _The latter is deferred — see [Tradeoffs and concerns](#tradeoffs-and-concerns) and [todo file](../../_todo/todo-manage-instruments-13-06-2026.md)._
- [Command: catalog-instrument](../../../domain-model/catalog/equipment/command.catalog-instrument.esdm.yaml): Create a new instrument with title, slug, and optional description.
- [Command: edit-instrument](../../../domain-model/catalog/equipment/command.edit-instrument.esdm.yaml): Partially update instrument fields (title, slug, description).
- [Command: archive-instrument](../../../domain-model/catalog/equipment/command.archive-instrument.esdm.yaml): Remove an instrument by id.
- [Event: instrument-cataloged](../../../domain-model/catalog/equipment/event.instrument-cataloged.esdm.yaml): Fired when an instrument is created.
- [Event: instrument-edited](../../../domain-model/catalog/equipment/event.instrument-edited.esdm.yaml): Fired when instrument details are updated.
- [Event: instrument-archived](../../../domain-model/catalog/equipment/event.instrument-archived.esdm.yaml): Fired when an instrument is removed.
- [Read Model: instrument](../../../domain-model/catalog/equipment/read-model.instrument.esdm.yaml): Projected instrument state for querying.
- [Actor: user](../../../domain-model/actors.esdm.yaml): Authenticated human performing write commands.

Modified Domain Models:

- [Aggregate: instrument](../../../domain-model/catalog/equipment/aggregate.instrument.esdm.yaml): `state` populated with `id`, `title`, `slug`, `description`. Invariant `no-archive-when-in-use` added.
- [Command: catalog-instrument](../../../domain-model/catalog/equipment/command.catalog-instrument.esdm.yaml): `data` populated with `title`, `slug`, `description` (required: title, slug).
- [Command: edit-instrument](../../../domain-model/catalog/equipment/command.edit-instrument.esdm.yaml): `data` populated with `title`, `slug`, `description` (partial update, no required fields). Constraint `instrument-exists` added.
- [Command: archive-instrument](../../../domain-model/catalog/equipment/command.archive-instrument.esdm.yaml): `data` populated with `id` (required). Constraint `instrument-exists` added.
- [Event: instrument-cataloged](../../../domain-model/catalog/equipment/event.instrument-cataloged.esdm.yaml): `data` populated with `id`, `title`, `slug`, `description` (required: id, title, slug).
- [Event: instrument-edited](../../../domain-model/catalog/equipment/event.instrument-edited.esdm.yaml): `data` populated with `id`, `title`, `slug`, `description` (required: id).
- [Event: instrument-archived](../../../domain-model/catalog/equipment/event.instrument-archived.esdm.yaml): `data` populated with `id` (required).
- [Read Model: instrument](../../../domain-model/catalog/equipment/read-model.instrument.esdm.yaml): `schema` populated with `id`, `title`, `slug`, `description` (required: id, title, slug).
- [Actor: guest](../../../domain-model/actors.esdm.yaml): Added for unauthenticated read access. Authorized only for querying the read model (read/list), no commands permitted.

New Domain Models:

- [Query: list-instruments](../../../domain-model/catalog/equipment/query.list-instruments.esdm.yaml): List all instruments with filtering by title, sorting, and pagination.
- [Query: read-instrument](../../../domain-model/catalog/equipment/query.read-instrument.esdm.yaml): Retrieve a single instrument by id or slug.
- [Feature: manage-instruments](../../../domain-model/catalog/equipment/feature.instrument-management.esdm.yaml): Given-When-Then specification for instrument management. Defines 6 scenarios covering catalog, edit, archive, validation, and rejection cases. Uses Aggregate variant scoped to `instrument`.

## Additional Requirements

### Functional Requirements

> The domain model invariant `no-archive-when-in-use` is **not enforced** in this iteration (see [Tradeoffs and concerns](#tradeoffs-and-concerns)). Archive is unconditional — always permitted.

There is no unarchive capability. The event remains in the event store for audit; the read model record is deleted.

## Non-requirements

- **No frontend implementation** — No changes to any frontend app are in scope. This spec covers only the backend (API service).
- **No apparatus changes** — The existing apparatus aggregate is untouched. Only the new instrument aggregate is built.
- **No unarchive** — Once archived (hard-deleted from read model), there is no way to restore an instrument. The event remains in the event store for audit, but no unarchive command or endpoint is provided.
- **No lifecycle beyond cataloged → edited → archived** — No approval workflow, no status field, no soft-delete.
- **No `use-instrument` or `withdraw-instrument`** — Associating instruments with sports is a separate feature and is out of scope. Instrument management (catalog, edit, archive) is independent of sport associations.
- **No admin-specific permissions** — The `admin` actor uses the same authorization rules as `user` for instrument operations. Admin-specific endpoints are not introduced.
- **No migration for existing data** — Since no instruments exist yet, no data migration is needed.
- **Archive guard not implemented** — The cross-aggregate invariant `no-archive-when-in-use` is not enforced in this iteration (see [tradeoffs](#tradeoffs-and-concerns)). Archive is unconditional.

## Quality Assurance

### Test Scenarios

#### Catalog an Instrument

```
Given the system is ready
 When a user submits a catalog-instrument command with title "Unicycle", slug "unicycle", and description "A single-wheeled vehicle"
 Then an instrument-cataloged event is created
  And an instrument read model is projected with those values
  And the response includes the instrument with id, title, slug, and description
```

> See scenario **`catalog-instrument`** in the [Given-When-Then specification](../../../domain-model/catalog/equipment/feature.instrument-management.esdm.yaml).

#### Edit an Instrument

```
Given an instrument "Unicycle" exists with slug "unicycle"
 When a user submits an edit-instrument command changing the title to "Einrad"
 Then an instrument-edited event is created with only the changed field
  And the instrument read model is updated to reflect the new title
  And the slug and description remain unchanged
```

> See scenario **`edit-instrument`** in the [Given-When-Then specification](../../../domain-model/catalog/equipment/feature.instrument-management.esdm.yaml).

#### Archive an Instrument

```
Given an instrument "Skateboard" exists
 When a user submits an archive-instrument command for "Skateboard"
 Then an instrument-archived event is created
  And the instrument read model is hard-deleted
```

> See scenario **`archive-instrument`** in the [Given-When-Then specification](../../../domain-model/catalog/equipment/feature.instrument-management.esdm.yaml).

#### Archive an Instrument When in Use by a Sport (deferred)

```
Given an instrument "Skateboard" exists
  And a sport "Skateboarding" uses "Skateboard" via use-instrument
 When a user submits an archive-instrument command for "Skateboard"
 Then the command is rejected because the invariant no-archive-when-in-use is violated
```

> See scenario **`archive-instrument-when-in-use`** in the [Given-When-Then specification](../../../domain-model/catalog/equipment/feature.instrument-management.esdm.yaml). This scenario is **not yet enforceable** — see [todo file](../../_todo/todo-manage-instruments-13-06-2026.md) for details on what needs to happen before it can be implemented.

#### Unauthenticated Read Access

```
Given an instrument exists
 When a guest sends a GET request to read or list instruments
  Then the response includes the instrument data (200 OK)
```

## Tradeoffs and Concerns

### Archive Guard Deferred

- **What:** The invariant `no-archive-when-in-use` — an instrument may only be archived when no sport references it — is not enforced in this iteration.
- **Why:** Enforcing this requires the `use-instrument` / `withdraw-instrument` commands on the `sport` aggregate to exist first. Those commands are out of scope.
- **Consequence:** Archive is unconditional. If a future feature introduces `use-instrument` before this guard is implemented, archiving an in-use instrument will silently succeed, violating the domain invariant.
- **Follow-up:** See the [todo file](../../_todo/todo-manage-instruments-13-06-2026.md) for prerequisites and resolution path.
