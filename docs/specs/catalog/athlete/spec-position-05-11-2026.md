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
- [Read Model: position](../../../domain-model/catalog/athlete/read-model.position.esdm.yaml): Projected view of the positions still in the catalog, carrying the derived `lookup_slug`
- [Query: read-position](../../../domain-model/catalog/athlete/query.read-position.esdm.yaml): Retrieve a single position by ID or lookup slug
- [Query: list-positions](../../../domain-model/catalog/athlete/query.list-positions.esdm.yaml): List positions with filtering, sorting, and pagination
- [Event: apparatus-edited](../../../domain-model/catalog/equipment/event.apparatus-edited.esdm.yaml): Referenced — re-derives the `lookup_slug` of positions bound to an apparatus whose slug changed
- [Event: instrument-edited](../../../domain-model/catalog/equipment/event.instrument-edited.esdm.yaml): Referenced — re-derives the `lookup_slug` of positions bound to an instrument whose slug changed
- [Read Model: apparatus](../../../domain-model/catalog/equipment/read-model.apparatus.esdm.yaml): Referenced — the source of the apparatus slug used to build a bound position's `lookup_slug`
- [Read Model: instrument](../../../domain-model/catalog/equipment/read-model.instrument.esdm.yaml): Referenced — the source of the instrument slug used to build a bound position's `lookup_slug`

### Aggregate: Position

A position represents a body position or stance in a sport context. It has the following characteristics:

- **Identity**: UUID-based identifier
- **Title**: Human-readable name (e.g., "Ready Stance", "Starting Block Position")
- **Slug**: The position's own URL-friendly identifier (raw, as supplied to `catalog-position` / `edit-position`); it is **not** the global key
- **Lookup Slug**: A derived, globally unique canonical path — `<equipment-slug>/<slug>` when the position is bound to equipment, the bare `<slug>` when it is not. It is built by the read-model projector (never supplied by a command) and is what `read-position` and clients navigate by
- **Description**: Optional detailed description
- **Equipment Reference**: Optional reference to either an apparatus or instrument (mutually exclusive)

### Invariants

The position aggregate enforces the following invariants:

1. **unique-slug-by-equipment**: No two positions may share the same lookup slug. The lookup slug namespaces the position's own slug by its referenced equipment's slug (`<equipment-slug>/<slug>`, or the bare `<slug>` when unbound). Because equipment slugs are themselves globally unique (the `unique-equipment-slug` invariant on apparatus and instrument), this reduces to: a position's raw slug must not repeat among positions bound to the **same** equipment, and a bound position's slug can never collide with an unbound one (the namespaced form carries a `/`). Uniqueness is therefore guaranteed **by construction**, not by a repair pass — which is why renaming an equipment cannot create a duplicate lookup slug.
2. **at-most-one-equipment**: A position can reference at most one piece of equipment (either apparatusId or instrumentId, but not both)

## Additional Requirements

### Functional Requirements

#### Catalog Position

- Accept title, slug (the position's **raw** slug — not namespaced), optional description, and optional equipment reference
- Validate that if equipment is referenced, it exists in the system
- Enforce the unique-slug-by-equipment invariant (reject if the derived lookup slug — `<equipment-slug>/<slug>` when bound, `<slug>` when unbound — already belongs to another cataloged position)
- Enforce the at-most-one-equipment invariant (reject if both apparatusId and instrumentId are provided)
- Emit a `position-cataloged` event carrying the raw slug; the projector derives `lookup_slug` from the referenced equipment's current slug
- Only users with the `user` role can execute this command

#### Edit Position

- Accept the position ID (required: it addresses the aggregate instance and is what the existence check reads) and any combination of: title, slug (raw), description, equipment reference
- Validate that the position exists before allowing edits; a deleted position is rejected as not found
- A reference the patch re-supplies is checked like a new one; a reference the patch does not carry is left alone (no cascade)
- Re-validate invariants after applying changes (unique-slug-by-equipment, at-most-one-equipment)
- Emit a `position-edited` event carrying the new raw slug; the projector re-derives `lookup_slug` from the new raw slug and the (possibly changed) referenced equipment's current slug
- Only users with the `user` role can execute this command

#### Equipment rename re-derives bound positions

- When referenced equipment is renamed (`apparatus-edited` / `instrument-edited`), the position projector re-derives the `lookup_slug` of every position bound to it, so the position's public path always tracks the equipment's **current** slug (`<new-equipment-slug>/<position-slug>`)
- This needs no position command and touches no position aggregate state — only the derived `lookup_slug` column moves
- The re-derivation can never produce a duplicate: equipment slugs are globally unique and each position's raw slug is unique within its equipment (see `unique-slug-by-equipment`), so a rename permutes namespaces, not values

#### Archive Position

- Accept the position ID (required: it addresses the aggregate instance and is what the existence check reads)
- Validate that the position exists before deleting it; an unknown or already deleted ID is rejected as not found
- Emit a `position-archived` event on success (the event name is historical: it records that the position left the catalog)
- Only users with the `admin` role can execute this command
- `archive-position` deletes the position: its row is removed from the position read model, so it no longer answers `read-position` and no longer appears in `list-positions`, and its slug becomes reusable
- There is no `archived` flag and no archived aggregate state; the event stays in the event store, and there is no unarchive operation

#### Read Position

- Retrieve a single position by either ID or **lookup slug** (the canonical `<equipment-slug>/<slug>` path, or the bare slug when unbound)
- Return the full position details, exposing `lookup_slug` as the position's public slug, including equipment references if present
- Answer not found for an ID or lookup slug that no longer has a position in the catalog, including one that was deleted
- Accessible to guests, users, and admins

#### List Positions

- Support filtering by title (case-insensitive partial match)
- Support sorting by fields using JSON:API sort syntax (e.g., `title`, `-title` for descending)
- Support pagination using JSON:API pagination (page number and page size)
- Expose `lookup_slug` as each position's public slug
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

- **Given** no position exists with lookup slug "ready-stance"
- **When** a user executes `catalog-position` with title "Ready Stance", slug "ready-stance", and description "Athletic stance with knees slightly bent"
- **Then** a `position-cataloged` event is emitted with the position data and the raw slug "ready-stance"
- **And** the position is available in the read model with `lookup_slug` "ready-stance" (no equipment namespace, because the position is unbound)
- **And** the position has no equipment reference

#### Scenario: Catalog a position with apparatus reference

**Reference**: [command.catalog-position.esdm.yaml](../../../domain-model/catalog/athlete/command.catalog-position.esdm.yaml)

- **Given** an apparatus "Starting Blocks" exists with slug "starting-blocks" and ID "abc-123"
- **And** no position bound to that apparatus exists with slug "take"
- **When** a user executes `catalog-position` with title "Starting Block Position", slug "take", and apparatusId "abc-123"
- **Then** a `position-cataloged` event is emitted with the raw slug "take" and apparatusId "abc-123"
- **And** the position read model carries `lookup_slug` "starting-blocks/take" and the apparatus reference

#### Scenario: Reject position with duplicate slug within the same equipment

**Reference**: [aggregate.position.esdm.yaml](../../../domain-model/catalog/athlete/aggregate.position.esdm.yaml) — invariant: unique-slug-by-equipment

- **Given** a position "take" is bound to apparatus "starting-blocks" (lookup slug "starting-blocks/take")
- **When** a user attempts to execute `catalog-position` with slug "take" and the same apparatusId
- **Then** the command is rejected
- **And** no event is emitted
- **And** an error indicates the slug must be unique for that equipment

#### Scenario: Same slug under different equipment is allowed

**Reference**: [aggregate.position.esdm.yaml](../../../domain-model/catalog/athlete/aggregate.position.esdm.yaml) — invariant: unique-slug-by-equipment

- **Given** a position "take" is bound to apparatus "starting-blocks"
- **And** a different apparatus "vaulting-box" exists
- **When** a user executes `catalog-position` with slug "take" and apparatusId of "vaulting-box"
- **Then** the command succeeds: the new position's lookup slug "vaulting-box/take" does not equal "starting-blocks/take"
- **And** both positions answer their own lookup slug independently

#### Scenario: Renaming referenced equipment re-derives the bound position's lookup slug

**Reference**: [read-model.position.esdm.yaml](../../../domain-model/catalog/athlete/read-model.position.esdm.yaml) — projection: apparatus-edited

- **Given** a position "take" is bound to apparatus "starting-blocks" (lookup slug "starting-blocks/take")
- **When** the apparatus is renamed so its slug becomes "starting-blocks-v2", emitting `apparatus-edited`
- **Then** the position's raw slug "take" is unchanged
- **And** the position's `lookup_slug` is re-derived to "starting-blocks-v2/take"
- **And** `read-position` by "starting-blocks/take" now answers not found, and by "starting-blocks-v2/take" returns the position

#### Scenario: Reject position with both apparatus and instrument

**Reference**: [aggregate.position.esdm.yaml](../../../domain-model/catalog/athlete/aggregate.position.esdm.yaml) — invariant: at-most-one-equipment

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

- **Given** a position exists with ID "pos-789", title "Lunge Position" and raw slug "lunge-position" (unbound, lookup slug "lunge-position")
- **When** an admin executes `archive-position` with id "pos-789"
- **Then** a `position-archived` event is emitted
- **And** the position is removed from the catalog: the read model no longer holds a row for it, and neither `read-position` nor `list-positions` returns it
- **And** the `position-archived` event remains in the event store — the deletion removes the catalog entry, not the history
- **When** a guest executes `read-position` with id "pos-789"
- **Then** the query answers not found
- **When** an admin executes `archive-position` with id "pos-789" again
- **Then** the command is rejected as not found — there is no archived state to re-archive and no unarchive operation
- **When** a user executes `catalog-position` with title "Lunge Position" and slug "lunge-position"
- **Then** the command succeeds, because the unique-slug-by-equipment invariant no longer sees the deleted position

#### Scenario: Read a position by lookup slug

**Reference**: [query.read-position.esdm.yaml](../../../domain-model/catalog/athlete/query.read-position.esdm.yaml)

- **Given** a position "handstand" bound to apparatus "parallel-bars" (lookup slug "parallel-bars/handstand")
- **When** a guest executes `read-position` with lookup slug "parallel-bars/handstand"
- **Then** the query returns the position with all its details, exposing `lookup_slug` as its slug

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

### Bound equipment cannot be archived while a position references it

- **What:** An apparatus or instrument cannot be archived (`archive-apparatus` / `archive-instrument`) while any position still references it. The guard is the equipment aggregate's `no-archive-when-in-use` invariant, extended to cover position references in addition to sport references.
- **Why:** A bound position's public path is `<equipment-slug>/<position-slug>`. The position does not copy the equipment slug — the projector derives `lookup_slug` from the equipment's **current** slug on every change. Archiving referenced equipment would leave the position naming equipment that can no longer be maintained, breaking that derivation. Preventing the archive keeps every bound position resolvable for the whole life of the reference, and removes the need for any orphan-flagging projection.
- **Consequence:** Equipment that is in use by a position is stuck until the positions referencing it are moved or archived first — the reference is a real precondition, checked cross-aggregate. The guard is enforced in `archive-apparatus` / `archive-instrument` (the equipment side), not in the position commands.
- **Follow-up:** [todo-manage-apparatuses](../../_todo/todo-manage-apparatuses-19-05-2026.md) and [todo-manage-instruments](../../_todo/todo-manage-instruments-13-06-2026.md) — the position half of `no-archive-when-in-use` is implementable once this position slice lands; the sport half stays blocked until `use-apparatus` / `use-instrument`.

### Renaming equipment rewrites the public paths of bound positions

- **What:** Renaming an equipment's slug re-derives the `lookup_slug` of every position bound to it (via the `apparatus-edited` / `instrument-edited` projections). A position's public URL therefore changes when its equipment is renamed.
- **Why:** Chosen deliberately — the canonical path always reflects the equipment's **current** slug (see "Equipment rename re-derives bound positions" under Additional Requirements), so paths stay human-coherent with the equipment they sit under.
- **Consequence:** A client's bookmarked position path changes when the equipment is renamed — an accepted cost of keeping the path coherent with the equipment. Delivering this behaviour means the position read model is fed by three aggregates (position, apparatus, instrument): the position projector must subscribe to `apparatus-edited` / `instrument-edited` and rewrite the `lookup_slug` of every position bound to the renamed equipment. Writing that multi-aggregate projector and its event subscription is part of building this feature, not a step to defer.
- **Scope:** The re-derivation can never create a duplicate (equipment slugs are globally unique and each raw slug is unique within its equipment), so no collision handling is needed. The projector clauses for `apparatus-edited` / `instrument-edited` are in-scope implementation work for this spec.

### Archive means delete

- **What:** `archive-position` removes the position from the catalog. There is no `archived` flag, no archived aggregate state, no "already archived" invariant, and no `archivedAt` timestamp in the read model.
- **Why:** The owner decided it, and the equipment constituents (apparatus, instrument) are the precedent — they already delete on archive — so the catalog's reference data follows one rule instead of two.
- **Consequence:** The continuity the earlier version of this spec claimed to protect is **not** preserved. A skill that referenced a deleted position points at an entry the catalog can no longer resolve: `read-position` answers not found, and the position's title and slug are gone from any queryable view. Only the event store keeps what the position was, and that is not reachable through the read model. The equipment precedent accepted the same loss, so dangling references are handled by the application layer.
- **Follow-up:** If real referential continuity is ever required, it has to come from a decision about how skills store position references (for example recording the position data on the skill at edit time), not from a flag on the position read model.
