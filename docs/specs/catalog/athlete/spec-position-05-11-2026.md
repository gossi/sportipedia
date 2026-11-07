---
feature: position
subdomain: catalog
composite: athlete
constituent: position
scope: backend
---

# Athlete Position Management

**Athlete position management enables the cataloging of body positions and stances used in sports skills, optionally bound to specific equipment. This is a foundational feature required for skill cataloging, as skills reference start and end positions.**

## Background

### Context

Sportipedia helps users with technical training in sports by cataloging movement skills and their components. A skill describes a movement pattern (e.g., a gymnastics element, a martial arts technique), and every skill has a start position and an end position.

Currently, the system lacks the ability to catalog and manage these positions independently. Without position management, we cannot properly catalog skills because skills depend on positions as their building blocks. This creates a blocker for the core use case: building a comprehensive catalog of sport skills.

The domain model defines a position as a body position or stance that may optionally reference a piece of equipment (apparatus or instrument). For example, a "ready stance" in basketball has no equipment, while a "starting block position" in sprinting references the starting blocks as equipment.

### Problem Statements

- **Skills cannot be cataloged** without a way to define and reference their start and end positions
- **No centralized position catalog** exists to manage positions as first-class entities in the system
- **Position reusability is impossible** when positions are embedded in skills, leading to duplication and inconsistency

## Domain Model

Used Domain Models:

- [Aggregate: Position](../../../domain-model/catalog/athlete/aggregate.position.esdm.yaml): A body position or stance, optionally bound to equipment
- [Command: catalog-position](../../../domain-model/catalog/athlete/command.catalog-position.esdm.yaml): Create a new position
- [Command: edit-position](../../../domain-model/catalog/athlete/command.edit-position.esdm.yaml): Update an existing position
- [Command: archive-position](../../../domain-model/catalog/athlete/command.archive-position.esdm.yaml): Delete a position from the catalog
- [Event: position-cataloged](../../../domain-model/catalog/athlete/event.position-cataloged.esdm.yaml): A position was created
- [Event: position-edited](../../../domain-model/catalog/athlete/event.position-edited.esdm.yaml): A position was updated
- [Event: position-archived](../../../domain-model/catalog/athlete/event.position-archived.esdm.yaml): A position was removed from the catalog
- [Read Model: position](../../../domain-model/catalog/athlete/read-model.position.esdm.yaml): Projected view of the positions still in the catalog
- [Query: read-position](../../../domain-model/catalog/athlete/query.read-position.esdm.yaml): Retrieve a single position by ID or slug
- [Query: list-positions](../../../domain-model/catalog/athlete/query.list-positions.esdm.yaml): List positions with filtering, sorting, and pagination

### Aggregate: Position

A position represents a body position or stance in a sport context. It has the following characteristics:

- **Identity**: UUID-based identifier
- **Title**: Human-readable name (e.g., "Ready Stance", "Starting Block Position")
- **Slug**: URL-friendly unique identifier
- **Description**: Optional detailed description
- **Equipment Reference**: Optional reference to either an apparatus or instrument (mutually exclusive)

### Invariants

The position aggregate enforces the following invariants:

1. **unique-slug**: The slug must be unique across all positions in the system. Because deleting a position takes it out of the catalog, the slug of a deleted position becomes available again
2. **at-most-one-equipment**: A position can reference at most one piece of equipment (either apparatusId or instrumentId, but not both)

## Additional Requirements

### Functional Requirements

#### Catalog Position

- Accept title, slug, optional description, and optional equipment reference
- Validate that if equipment is referenced, it exists in the system
- Enforce the unique-slug invariant (reject if slug already exists)
- Enforce the at-most-one-equipment invariant (reject if both apparatusId and instrumentId are provided)
- Emit a `position-cataloged` event on success
- Only users with the `user` role can execute this command

#### Edit Position

- Accept the position ID (required: it addresses the aggregate instance and is what the existence check reads) and any combination of: title, slug, description, equipment reference
- Validate that the position exists before allowing edits; a deleted position is rejected as not found
- A reference the patch re-supplies is checked like a new one; a reference the patch does not carry is left alone (no cascade)
- Re-validate invariants after applying changes (unique-slug, at-most-one-equipment)
- Emit a `position-edited` event on success
- Only users with the `user` role can execute this command

#### Archive Position

- Accept the position ID (required: it addresses the aggregate instance and is what the existence check reads)
- Validate that the position exists before deleting it; an unknown or already deleted ID is rejected as not found
- Emit a `position-archived` event on success (the event name is historical: it records that the position left the catalog)
- Only users with the `admin` role can execute this command
- `archive-position` deletes the position: its row is removed from the position read model, so it no longer answers `read-position` and no longer appears in `list-positions`, and its slug becomes reusable
- There is no `archived` flag and no archived aggregate state; the event stays in the event store, and there is no unarchive operation

#### Read Position

- Retrieve a single position by either ID or slug
- Return the full position details including equipment references if present
- Answer not found for an ID or slug that no longer has a position in the catalog, including one that was deleted
- Accessible to guests, users, and admins

#### List Positions

- Support filtering by title (case-insensitive partial match)
- Support sorting by fields using JSON:API sort syntax (e.g., `title`, `-title` for descending)
- Support pagination using JSON:API pagination (page number and page size)
- Return only the positions currently in the catalog: a deleted position has no row to exclude, so no "exclude archived" filter is needed
- Accessible to guests, users, and admins

### Technical Requirements

- All commands follow the CQRS/ES architecture pattern defined in [ARCHITECTURE.md](../../../../ARCHITECTURE.md)
- Events are persisted to EventStoreDB
- Read models are projected into PostgreSQL for efficient querying
- API endpoints follow JSON:API specification
- Authentication and authorization handled by Better Auth service

## Non-requirements

The following are explicitly out of scope for this feature:

- **Frontend UI**: This spec covers backend API only; frontend implementation is separate
- **Skill integration**: While positions are used by skills, this spec does not cover how skills reference positions
- **Bulk operations**: No bulk import/export of positions
- **Unarchive / restore**: A deleted position is not brought back. There is no restore command and no archived state to return from
- **Lookup of deleted positions**: The `position-archived` event keeps the history in the event store, but no query exposes it; this spec adds no "find by id including deleted" read
- **Position hierarchies**: No parent-child relationships between positions
- **Position templates**: No template or pattern system for positions
- **Position usage tracking**: No tracking of which skills use which positions (handled by skill aggregate)

## Quality Assurance

### Test Scenarios

#### Scenario: Catalog a position without equipment

**Reference**: [command.catalog-position.esdm.yaml](../../../domain-model/catalog/athlete/command.catalog-position.esdm.yaml)

- **Given** no position exists with slug "ready-stance"
- **When** a user executes `catalog-position` with title "Ready Stance", slug "ready-stance", and description "Athletic stance with knees slightly bent"
- **Then** a `position-cataloged` event is emitted with the position data
- **And** the position is available in the read model
- **And** the position has no equipment reference

#### Scenario: Catalog a position with apparatus reference

**Reference**: [command.catalog-position.esdm.yaml](../../../domain-model/catalog/athlete/command.catalog-position.esdm.yaml)

- **Given** an apparatus "Starting Blocks" exists with ID "abc-123"
- **And** no position exists with slug "starting-block-position"
- **When** a user executes `catalog-position` with title "Starting Block Position", slug "starting-block-position", and apparatusId "abc-123"
- **Then** a `position-cataloged` event is emitted with apparatusId "abc-123"
- **And** the position read model includes the apparatus reference

#### Scenario: Reject position with duplicate slug

**Reference**: [aggregate.position.esdm.yaml](../../../domain-model/catalog/athlete/aggregate.position.esdm.yaml) - invariant: unique-slug

- **Given** a position exists with slug "guard-position"
- **When** a user attempts to execute `catalog-position` with slug "guard-position"
- **Then** the command is rejected
- **And** no event is emitted
- **And** an error indicates the slug must be unique

#### Scenario: Reject position with both apparatus and instrument

**Reference**: [aggregate.position.esdm.yaml](../../../domain-model/catalog/athlete/aggregate.position.esdm.yaml) - invariant: at-most-one-equipment

- **Given** an apparatus and an instrument exist in the system
- **When** a user attempts to execute `catalog-position` with both apparatusId and instrumentId
- **Then** the command is rejected
- **And** no event is emitted
- **And** an error indicates only one equipment reference is allowed

#### Scenario: Edit an existing position

**Reference**: [command.edit-position.esdm.yaml](../../../domain-model/catalog/athlete/command.edit-position.esdm.yaml)

- **Given** a position exists with ID "pos-456" and title "Old Title"
- **When** a user executes `edit-position` with id "pos-456" and title "New Title"
- **Then** a `position-edited` event is emitted with the updated title
- **And** the position read model reflects the new title

#### Scenario: Archive (delete) a position

**Reference**: [command.archive-position.esdm.yaml](../../../domain-model/catalog/athlete/command.archive-position.esdm.yaml)

- **Given** a position exists with ID "pos-789", title "Lunge Position" and slug "lunge-position"
- **When** an admin executes `archive-position` with id "pos-789"
- **Then** a `position-archived` event is emitted
- **And** the position is removed from the catalog: the read model no longer holds a row for it, and neither `read-position` nor `list-positions` returns it
- **And** the `position-archived` event remains in the event store — the deletion removes the catalog entry, not the history
- **When** a guest executes `read-position` with id "pos-789"
- **Then** the query answers not found
- **When** an admin executes `archive-position` with id "pos-789" again
- **Then** the command is rejected as not found — there is no archived state to re-archive and no unarchive operation
- **When** a user executes `catalog-position` with title "Lunge Position" and slug "lunge-position"
- **Then** the command succeeds, because the unique-slug invariant no longer sees the deleted position

#### Scenario: Read a position by slug

**Reference**: [query.read-position.esdm.yaml](../../../domain-model/catalog/athlete/query.read-position.esdm.yaml)

- **Given** a position exists with slug "handstand"
- **When** a guest executes `read-position` with slug "handstand"
- **Then** the query returns the position with all its details

#### Scenario: List positions with filtering

**Reference**: [query.list-positions.esdm.yaml](../../../domain-model/catalog/athlete/query.list-positions.esdm.yaml)

- **Given** multiple positions exist with various titles
- **When** a user executes `list-positions` with filter title "stance"
- **Then** the query returns only positions whose title contains "stance" (case-insensitive)

#### Scenario: List positions with pagination

**Reference**: [query.list-positions.esdm.yaml](../../../domain-model/catalog/athlete/query.list-positions.esdm.yaml)

- **Given** 25 positions exist in the system
- **When** a user executes `list-positions` with page.number 2 and page.size 10
- **Then** the query returns positions 11-20

## Tradeoffs and Concerns

### No cascade delete on equipment deletion

- **What:** When equipment is deleted (`archive-apparatus` / `archive-instrument`), positions referencing it are not automatically updated or deleted
- **Why:** Positions are independent aggregates with their own lifecycle. Automatic cascade would violate aggregate boundaries and create hidden dependencies.
- **Consequence:** Positions may reference non-existent equipment. The application layer must handle this gracefully (e.g., display "unknown equipment" or filter out orphaned positions).
- **Follow-up:** Consider adding a validation process or read-model projection that flags positions with missing equipment references.

### Archive means delete

- **What:** `archive-position` removes the position from the catalog. There is no `archived` flag, no archived aggregate state, no "already archived" invariant, and no `archivedAt` timestamp in the read model.
- **Why:** The owner decided it, and the equipment constituents (apparatus, instrument) are the precedent — they already delete on archive — so the catalog's reference data follows one rule instead of two.
- **Consequence:** The continuity the earlier version of this spec claimed to protect is **not** preserved. A skill that referenced a deleted position points at an entry the catalog can no longer resolve: `read-position` answers not found, and the position's title and slug are gone from any queryable view. Only the event store keeps what the position was, and that is not reachable through the read model. The equipment precedent accepted the same loss, so dangling references are handled by the application layer, exactly as they are for equipment (see "No cascade delete on equipment deletion").
- **Follow-up:** If real referential continuity is ever required, it has to come from a decision about how skills store position references (for example recording the position data on the skill at edit time), not from a flag on the position read model.

### No position versioning

- **What:** Editing a position updates it in place rather than creating a new version
- **Why:** Positions are reference data that skills point to. Versioning would complicate skill-position relationships unnecessarily.
- **Consequence:** If a position's meaning changes significantly, it cannot be tracked historically. This is acceptable for the current use case.
- **Follow-up:** If versioning becomes necessary, reconsider the aggregate design and skill-position relationship model.
