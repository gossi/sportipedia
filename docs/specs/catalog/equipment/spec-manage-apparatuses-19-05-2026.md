---
title: Manage Apparatuses in the Backend
feature: manage-apparatuses
subdomain: catalog
composite: equipment
scope: backend
---

# Manage Apparatuses in the Backend

**Build the complete backend for the `apparatus` aggregate — domain logic (CQRS/ES), JSON:API web endpoints, and API client requests — so that sports equipment (immovable apparatuses) can be cataloged, edited, listed, read, and archived by the system.**

## Background

### Context

The Sportipedia catalog subdomain distinguishes two types of sports equipment:

- **Instruments** — movable equipment the athlete controls (e.g., a unicycle, skateboard, tennis racket). Backend implementation already exists and is working.
- **Apparatuses** — immovable equipment the athlete interacts with but never moves (e.g., a gymnastics beam, climbing wall, pommel horse). The domain model (ESDM yaml files) is fully defined in terms of aggregate, commands, events, and read model, but **zero backend code exists**.

The `instrument` backend serves as a proven, complete reference implementation following the project's CQRS/ES architecture (Commanded framework, Elixir/Phoenix). The `apparatus` aggregate is structurally analogous in its domain model, making this a straightforward implementation that should follow the exact same patterns.

Currently, the system cannot manage apparatuses — they only exist as abstract ESDM definitions. This gap blocks any feature that depends on apparatus data (e.g., associating apparatuses with skills or exercises, or displaying apparatus information).

### Problem Statements

- Apparatuses cannot be cataloged — there is no backend code to accept and persist apparatus data.
- Apparatuses cannot be queried — neither listing all apparatuses nor reading a single apparatus by ID is possible.
- Apparatuses cannot be edited or archived — there is no way to update apparatus metadata or remove unused ones.
- API consumers (frontend, admin tools, third-party integrations) have no endpoints to interact with apparatus data.

## Domain Model

Used Domain Models:

- [Aggregate: apparatus](../../../domain-model/catalog/equipment/aggregate.apparatus.esdm.yaml): Root aggregate for immovable sport equipment. Defines invariants `unique-slug` (slug must be unique) and `no-archive-when-in-use` (apparatus can only be archived when no sport references it). _The latter is deferred — see [Tradeoffs and concerns](#tradeoffs-and-concerns) and [todo file](../../_todo/todo-manage-apparatuses-19-05-2026.md)._
- [Command: catalog-apparatus](../../../domain-model/catalog/equipment/command.catalog-apparatus.esdm.yaml): Create a new apparatus with title, slug, and optional description.
- [Command: edit-apparatus](../../../domain-model/catalog/equipment/command.edit-apparatus.esdm.yaml): Partially update apparatus fields (title, slug, description).
- [Command: archive-apparatus](../../../domain-model/catalog/equipment/command.archive-apparatus.esdm.yaml): Remove an apparatus by id.
- [Event: apparatus-cataloged](../../../domain-model/catalog/equipment/event.apparatus-cataloged.esdm.yaml): Fired when an apparatus is created.
- [Event: apparatus-edited](../../../domain-model/catalog/equipment/event.apparatus-edited.esdm.yaml): Fired when apparatus details are updated.
- [Event: apparatus-archived](../../../domain-model/catalog/equipment/event.apparatus-archived.esdm.yaml): Fired when an apparatus is removed.
- [Read Model: apparatus](../../../domain-model/catalog/equipment/read-model.apparatus.esdm.yaml): Projected apparatus state for querying.
- [Actor: user](../../../domain-model/actors.esdm.yaml): Authenticated human performing write commands.

Modified Domain Models:

- [Aggregate: apparatus](../../../domain-model/catalog/equipment/aggregate.apparatus.esdm.yaml): `state` populated with `id`, `title`, `slug`, `description`. Invariant `no-archive-when-in-use` added.
- [Command: catalog-apparatus](../../../domain-model/catalog/equipment/command.catalog-apparatus.esdm.yaml): `data` populated with `title`, `slug`, `description` (required: title, slug).
- [Command: edit-apparatus](../../../domain-model/catalog/equipment/command.edit-apparatus.esdm.yaml): `data` populated with `title`, `slug`, `description` (partial update, no required fields).
- [Command: archive-apparatus](../../../domain-model/catalog/equipment/command.archive-apparatus.esdm.yaml): `data` populated with `id` (required).
- [Event: apparatus-cataloged](../../../domain-model/catalog/equipment/event.apparatus-cataloged.esdm.yaml): `data` populated with `id`, `title`, `slug`, `description` (required: id, title, slug).
- [Event: apparatus-edited](../../../domain-model/catalog/equipment/event.apparatus-edited.esdm.yaml): `data` populated with `id`, `title`, `slug`, `description` (required: id).
- [Event: apparatus-archived](../../../domain-model/catalog/equipment/event.apparatus-archived.esdm.yaml): `data` populated with `id` (required).
- [Read Model: apparatus](../../../domain-model/catalog/equipment/read-model.apparatus.esdm.yaml): `schema` populated with `id`, `title`, `slug`, `description` (required: id, title, slug).
- [Actor: guest](../../../domain-model/actors.esdm.yaml): Added for unauthenticated read access. Authorized only for querying the read model (read/list), no commands permitted.

New Domain Models:

- [Feature: manage-apparatuses](../../../domain-model/catalog/equipment/feature.apparatus-management.esdm.yaml): Given-When-Then specification for apparatus management. Defines 7 scenarios covering catalog, edit, archive, validation, and rejection cases. Uses Aggregate variant scoped to `apparatus`.

## Additional Requirements

### Functional Requirements

> The domain model invariant `no-archive-when-in-use` is **not enforced** in this iteration (see [Tradeoffs and concerns](#tradeoffs-and-concerns)). Archive is unconditional — always permitted.

There is no unarchive capability. The event remains in the event store for audit; the read model record is deleted.

## Non-requirements

- **No frontend implementation** — No changes to any frontend app are in scope. This spec covers only the backend (API service).
- **No instrument changes** — The existing instrument aggregate is untouched. Only the new apparatus aggregate is built.
- **No unarchive** — Once archived (hard-deleted from read model), there is no way to restore an apparatus. The event remains in the event store for audit, but no unarchive command or endpoint is provided.
- **No lifecycle beyond cataloged → edited → archived** — No approval workflow, no status field, no soft-delete.
- **No `use-apparatus` or `withdraw-apparatus`** — Associating apparatuses with sports is a separate feature and is out of scope. Apparatus management (catalog, edit, archive) is independent of sport associations.
- **No admin-specific permissions** — The `admin` actor uses the same authorization rules as `user` for apparatus operations. Admin-specific endpoints are not introduced.
- **No migration for existing data** — Since no apparatuses exist yet, no data migration is needed.
- **Archive guard not implemented** — The cross-aggregate invariant `no-archive-when-in-use` is not enforced in this iteration (see [tradeoffs](#tradeoffs-and-concerns)). Archive is unconditional.

## Quality Assurance

### Test Scenarios

#### Catalog an Apparatus

```
Given the system is ready
 When a user submits a catalog-apparatus command with title "Vaulting Table", slug "vaulting-table", and description "A gymnastics vault"
 Then an apparatus-cataloged event is created
  And an apparatus read model is projected with those values
  And the response includes the apparatus with id, title, slug, and description
```

> See scenario **`catalog-apparatus`** in the [Given-When-Then specification](../../../domain-model/catalog/equipment/feature.apparatus-management.esdm.yaml).

#### Edit an Apparatus

```
Given an apparatus "Vaulting Table" exists with slug "vaulting-table"
 When a user submits an edit-apparatus command changing the title to "Vault"
 Then an apparatus-edited event is created with only the changed field
  And the apparatus read model is updated to reflect the new title
  And the slug and description remain unchanged
```

> See scenario **`edit-apparatus`** in the [Given-When-Then specification](../../../domain-model/catalog/equipment/feature.apparatus-management.esdm.yaml).

#### Archive an Apparatus

```
Given an apparatus "Balance Beam" exists
 When a user submits an archive-apparatus command for "Balance Beam"
 Then an apparatus-archived event is created
  And the apparatus read model is hard-deleted
```

> See scenario **`archive-apparatus`** in the [Given-When-Then specification](../../../domain-model/catalog/equipment/feature.apparatus-management.esdm.yaml).

#### Archive an Apparatus When in Use by a Sport (deferred)

```
Given an apparatus "Balance Beam" exists
  And a sport "Gymnastics" uses "Balance Beam" via use-apparatus
 When a user submits an archive-apparatus command for "Balance Beam"
 Then the command is rejected because the invariant no-archive-when-in-use is violated
```

> See scenario **`archive-apparatus-when-in-use`** in the [Given-When-Then specification](../../../domain-model/catalog/equipment/feature.apparatus-management.esdm.yaml). This scenario is **not yet enforceable** — see [todo file](../../_todo/todo-manage-apparatuses-19-05-2026.md) for details on what needs to happen before it can be implemented.

#### Unauthenticated Read Access

```
Given an apparatus exists
 When a guest sends a GET request to read or list apparatuses
  Then the response includes the apparatus data (200 OK)
```

## Tradeoffs and Concerns

### Archive Guard Deferred

- **What:** The invariant `no-archive-when-in-use` — an apparatus may only be archived when no sport references it — is not enforced in this iteration.
- **Why:** Enforcing this requires the `use-apparatus` / `withdraw-apparatus` commands on the `sport` aggregate to exist first. Those commands are out of scope.
- **Consequence:** Archive is unconditional. If a future feature introduces `use-apparatus` before this guard is implemented, archiving an in-use apparatus will silently succeed, violating the domain invariant.
- **Follow-up:** See the [todo file](../../_todo/todo-manage-apparatuses-19-05-2026.md) for prerequisites and resolution path.
