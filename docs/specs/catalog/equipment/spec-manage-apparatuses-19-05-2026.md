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

## Requirements

### Functional Requirements

- **Catalog an Apparatus** — Users must be able to create a new apparatus with fields: `title` (required), `slug` (required, unique), `description` (optional). Returns the created apparatus with server-generated UUID.
- **Edit an Apparatus** — Users must be able to partially update any subset of apparatus fields (`title`, `slug`, `description`). Requires `id`. Slug uniqueness must be enforced when slug is being changed.
- **Archive an Apparatus** — Users must be able to archive (hard-delete from read model) an apparatus. Requires `id`.

  > The domain model invariant `no-archive-when-in-use` is **not enforced** in this iteration (see [Tradeoffs and concerns](#tradeoffs-and-concerns)). Archive is unconditional — always permitted.

  There is no unarchive capability. The event remains in the event store for audit; the read model record is deleted.

- **Read an Apparatus** — Any actor (including unauthenticated guests) can read a single apparatus by its UUID. Returns the apparatus with all fields.
- **List Apparatuses** — Any actor (including unauthenticated guests) can list all apparatuses. Supports JSON:API filtering (by `title`) and sorting (by `title`).

### Technical Requirements

- **Architecture Compliance** — Must follow the existing CQRS/ES architecture using the `Commanded` framework, matching the `instrument` implementation pattern exactly: Aggregate, Command, Command Handler, Event, Projector, Read Model, Public API, Policy, Validator, Query.
- **Event Sourcing** — All state mutations must be captured as events in the event store using the existing `Sportipedia.Catalog` Commanded application. Aggregate identity prefix: `equipment/apparatus/`.
- **Read Model** — An Ecto schema `ApparatusReadModel` in the `catalog` schema prefix with table `apparatus`. Fields: `id` (binary_id, PK), `title` (string, not null), `slug` (string, not null, unique), `description` (string, nullable), `inserted_at`, `updated_at`.
- **Projector** — An `ApparatusProjector` using `Commanded.Projections.Ecto` with consistency `:strong`, name `"equipment.apparatus_projection"`. Must handle all three events: insert on `ApparatusCataloged`, update on `ApparatusEdited`, delete on `ApparatusArchived`.
- **Unique Slug Validation** — A `UniqueSlug` validator that queries the read model for slug existence before allowing catalog or edit commands. Must guard against race conditions via database unique constraint.
- **Authorization** — Implement `ApparatusPolicy` using Bodyguard:
  - `catalog_apparatus`: authenticated user only
  - `edit_apparatus`: authenticated user only
  - `archive_apparatus`: authenticated user only
  - `read_apparatus`: any (including guest/unauthenticated)
  - `list_apparatuses`: any (including guest/unauthenticated)

### Integration Requirements

- **Web Controller** — `ApparatusController` under `SportipediaWeb.Catalog.Equipment` with 5 actions:
  - `POST /catalog/equipment/apparatuses/catalog-apparatus` → `:catalog_apparatus`
  - `POST /catalog/equipment/apparatuses/edit-apparatus` → `:edit_apparatus`
  - `POST /catalog/equipment/apparatuses/archive-apparatus` → `:archive_apparatus`
  - `GET /catalog/equipment/apparatuses` → `:list_apparatuses`
  - `GET /catalog/equipment/apparatuses/:id` → `:read_apparatus`
- **JSON:API View** — `ApparatusView` with type `"apparatuses"`, path `"catalog/equipment/apparatuses"`, fields: `:title`, `:description`, `:slug`.
- **OpenAPI Schemas** — `ApparatusResponse` (single) and `ApparatusListResponse` (collection), titled `"equipment.Apparatus"` and `"equipment.Apparatuses"`.
- **Router** — Add scope under `/catalog/equipment/apparatuses` in `router.ex`, mirroring the instrument route structure.

### Documentation

- **Bruno API Collection** — Add 5 request files under `bruno/Catalog/Equipment/`:
  - `Catalog Apparatus.yml` (seq: 6)
  - `Edit Apparatus.yml` (seq: 7)
  - `Archive Apparatus.yml` (seq: 8)
  - `List Apparatuses.yml` (seq: 9)
  - `Read Apparatus.yml` (seq: 10)

  Following the exact YAML format of the instrument Bruno files: JSON:API body, auth inheritance from parent folder, example responses.

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

### Implementation Tests

- **Domain Feature Tests** — Three test files under `test/sportipedia/catalog/equipment/apparatus/features/`:
  - `catalog_apparatus_test.exs` — Policy, Command validation, Handler, Event, Aggregate apply, Projector, Public API (unit + integration tags)
  - `edit_apparatus_test.exs` — Policy, Command validation, Handler, Event (get_changes, JSON encoding), Aggregate apply (partial updates), Projector, Public API
  - `archive_apparatus_test.exs` — Policy, Command validation, Handler, Event, Aggregate apply, Projector, Public API

- **Request Tests** — Three test files under `test/sportipedia_web/catalog/equipment/`:
  - `catalog_apparatus_request_test.exs` — Authenticated success, 403 unauthenticated, 422 missing fields, 422 duplicate slug
  - `edit_apparatus_request_test.exs` — Authenticated update, partial update, 403 unauthenticated, 404 on slug conflict
  - `archive_apparatus_request_test.exs` — Authenticated archive, 403 unauthenticated, 204 on not-found

- **Schema and View Tests** — Two test files under `test/sportipedia_web/catalog/equipment/`:
  - `apparatus_schema_test.exs` — Schema titles and structure
  - `apparatus_view_test.exs` — View type/fields/path, render single and collection, GET read and list endpoint behavior

## Tradeoffs and concerns

### Archive guard cannot be implemented in this iteration

The domain model defines the invariant `no-archive-when-in-use` on the `apparatus` aggregate: an apparatus may only be archived when no sport references it via `use-apparatus`. Enforcing this requires a cross-aggregate query against the sport read model.

This guard **cannot be implemented now** because the mechanism to associate an apparatus with a sport (`use-apparatus` / `withdraw-apparatus` commands on the `sport` aggregate) is out of scope. Without those commands, no sport will ever reference an apparatus, making the guard query always return zero results — dead code.

**Consequence:** Archive is unconditional in this iteration. If a future feature introduces `use-apparatus` and associates an apparatus with a sport before this guard is implemented, archiving that apparatus will silently succeed, violating the domain invariant and leaving the sport with a dangling reference.

**Follow-up:** A dedicated [todo file](../../_todo/todo-manage-apparatuses-19-05-2026.md) tracks the prerequisites, implementation steps, and resolution path for this guard. It must be implemented as part of or immediately after the feature that introduces `use-apparatus`/`withdraw-apparatus`.


