---
status: draft
date: 2026-11-21
decision-makers: [thomas]
consulted: []
informed: []
---

# Model Relationships with `x-esdm-relation` on Read Models

## Context and Problem Statement

ESDM core has no vocabulary for relationships. A field like `apparatus_id` on a read model is an inert string to the schema; nothing in the model says it links positions to apparatus. Sportipedia's domain is full of those links, and the existing sparch extension `x-esdm-relation` (with `to`, `cardinality`, `inverse`) only covers the simple n:1 case and is only read by the TypeScript generator. The Elixir side drops it entirely: Ecto read models carry plain camelCase id columns with no associations, the JSON:API views render raw ids as attributes, and the spec itself says keys that reference related resources should not be attributes. Commands and events legitimately deal in ids (they are committed facts, replayed in unpredictable order), so the ids must not disappear; the question is how the model states the relationship between them so that the generators produce idiomatic Ecto associations, standard JSON:API documents, and correct WarpDrive schemas without guessing.

## Decision Drivers

- Decisions a generator needs must be declared in the model, never guessed (the founding rule of the sparch extensions)
- ESDM core documents reject unknown top-level keys, so vocabulary can only grow as annotations inside the unconstrained `schema` block; ESDM's own `x-esdm-*` keys set that precedent
- All four stored Ecto association kinds must be expressible: `belongs_to`, `has_one`, `has_many`, `many_to_many` (embedded documents are excluded; they are nested properties, not relations)
- Two different relationships may exist between the same two models (a position bound to a stationary apparatus and a mobile one), so a relation's name cannot come from its target
- One fact should have one name across layers: database column, Ecto association, JSON:API relationship key, frontend property
- Commands and events carry ids, not objects, and stay untouched by the relationship vocabulary
- Projection tables are rebuilt by event replay; database-level foreign keys between them would break rehydration (Commanded and the event-sourcing community are explicit about this)
- Migrations stay hand-written; sparch assists but never writes them

## Considered Options

- Explicit relation vocabulary in `x-esdm-relation`, declared on read model schema properties only
- Derivation: infer kinds and pairings from `cardinality`, target names, and naming grammars (like collections named `stationary_positions` singularizing to the edge `stationary`)
- First-class relationship elements outside the schema properties (a `relationships` block per model)
- Do nothing: relationships stay plain id fields with hand-written associations

## Decision Outcome

Chosen option: "Explicit relation vocabulary in `x-esdm-relation`, declared on read model schema properties only", because it is the only option that states every decision a generator needs while staying valid ESDM (annotations inside the `schema` block, which core validators do not police) and while keeping one uniform naming rule across all layers.

### Vocabulary

The extension carries `to`, `kind`, `inverse`, `column`, `join_table`, `join_model`. It appears only on read model schema properties. Commands, events, and aggregate state keep plain id fields; any older annotations on them have lost their meaning and are ignored, not policed.

```yaml
# position: two relationships to one target, distinct names
stationary:
  type: string
  format: uuid
  x-esdm-relation: { to: apparatus, kind: belongs_to }
mobile:
  type: string
  format: uuid
  x-esdm-relation: { to: apparatus, kind: belongs_to, column: carried_apparatus_id }

# apparatus: the parent side, virtual (no column, never cast)
stationary_positions:
  type: array
  items: { type: string, format: uuid }
  x-esdm-relation: { to: position, kind: has_many, inverse: stationary }
certification:
  type: string
  format: uuid
  x-esdm-relation: { to: apparatus-certification, kind: has_one, inverse: apparatus }

# many_to_many, plain (derived join table) or modeled (its own read model)
tags:
  type: array
  items: { type: string, format: uuid }
  x-esdm-relation: { to: tag, kind: many_to_many, join_table: movements_tags }
apparatuses:
  type: array
  items: { type: string, format: uuid }
  x-esdm-relation: { to: apparatus, kind: many_to_many, join_model: movement-apparatus-usage }
```

Rules that go with it:

- `kind` (`belongs_to | has_one | has_many | many_to_many`) mirrors Ecto's four macros one to one.
- The property name is the relation key. It names the Ecto association, the JSON:API relationship key, and the frontend property. `to` supplies the target (module, type) only, never a name.
- `column` names the database field on the `belongs_to` side, derived as `<key>_id` when omitted. It is the only spelling that stays below the database: the frontend and the events never see it. (The camelCase id properties in today's models were a mistake; properties move to snake_case generally.)
- `inverse` names the property on the far side. It is required on `has_one`, `has_many`, and `many_to_many`, optional on `belongs_to`, where absence means unidirectional. Keeping it was decided after research: derivation from pairing works only while one edge connects two models, and the multi-edge case is exactly what this vocabulary must express. WarpDrive itself requires a declared `inverse` and pairs by name-matching, with documented silent-mispairing hazards.
- `join_table` (derived from both table names when omitted) is the anonymous link. `join_model` names an ordinary read model with exactly two `belongs_to` properties; it owns its rows through its own commands and events. The two values exclude each other.

### Naming across layers

One sentence: keys name things, `to` names types, `_id` marks ids. Commands, events, and aggregate state carry the relation key plus `_id` for to-one and plus `_ids` for to-many sets (`stationary_id`, `tag_ids`). This follows the convention found in Commanded samples, Ecto and Rails association naming, and event-sourcing writing (role names win over target-type names when a concept plays several roles).

### Generation behavior

- Ecto read models: relation kinds become association macros; `belongs_to` keeps its column (`<key>_id` or the `column` override) in the changeset casts, the three parent kinds generate only the association and never a column or cast.
- No database foreign keys, no `on_delete` vocabulary. Existence of a referenced id stays an aggregate invariant checked in the command path. `has_one` earns a unique index on the child's column; returning `belongs_to` columns earn indexes.
- JSON:API: relations render as `relationships` (linkage in responses and requests), never as id attributes. `include` is opt-in with the capability generated. The controller is the single translation point from linkage to command params (`data.relationships.stationary.data.id` to `"stationary_id"`); the projector is the only other, from `<key>_id` to `column`, and it activates solely when `column` overrides the derivation. OpenAPI schemas derived from views render linkage objects.
- `many_to_many` without `join_model`: events carry the complete set (`tag_ids`), the projector generates a replay-safe replace unit (delete all, insert all). With `join_model`, the link model's own commands write the rows and a parent-side set is refused.
- WarpDrive schemas keep the legacy-mode output of today (the framework's Polaris relationships are unfinished: collection fields throw "not yet implemented" in core 5.9.1). `kind` and `inverse` options are computed from the declarations, camel-matched to the frontend properties.
- `sparch validate` checks integrity only: resolution and shape per kind, `column`/`join_*` applicability, the pairing both sides describe the same edge, join table collisions, and the command/event correlation that reports a field ending `_id`/`_ids` referencing nothing. The last one is what catches half-renamed relations when the model changes.
- New command `sparch migration <read-model>` prints the whole-table create migration as it would be written today, including the relation-derived columns, indexes, and join tables. Migrations themselves stay hand-written; auditing them against the reconstruction is deferred.

## Consequences

### Good

- Generated Ecto is idiomatic: preload, joins, and `assoc` work; camelCase column atoms are gone
- API documents follow the JSON:API standard in both directions, and the frontend's resolved objects (`stationary?: Apparatus`) finally have a real transport
- Two relations between the same pair of models are expressible everywhere without naming games
- Model errors surface as `sparch validate` findings, not as wrong generated code or replay failures
- Commands, events, and aggregates stay exactly as they were: facts carry ids

### Bad

- Breaking vocabulary change: every existing `x-esdm-relation` in the corpus and docs needs `kind`, and snake_case renaming touches read models, commands, events, aggregates, and (hand-written) migrations
- The field-convention coupling between command/event fields and relation keys (`<key>_id`) is the one place a rename can break silently, mitigated by the "references nothing" finding but still convention-dependent
- No database integrity means dangling ids stay possible, deliberately, and queries must tolerate them (a preloaded relation of a dangling id is simply `nil`)
- The request-side relationship linkage needs controller translation that the vendored `JSONAPI.Utils.DataToParams` does not provide in our spelling; it is generated ourselves

### Neutral

- Polaris-mode output becomes a rendering change in one blueprint once WarpDrive finishes its relationship support; the model already carries every fact those options need
- Migration drift checking (replaying migration files against the model) is an accepted idea, to be designed in its own session

## Confirmation

- `sparch validate` reports the integrity rules above; the real model must validate clean after the corpus migration
- Acceptance tests in `tools/sparch` cover each relation kind, the two-edges-to-one-target case with a `column` override, and both join styles, driven by an extended fixture corpus in `tools/sparch/fixtures/domain-model`
- The build is confined to `tools/sparch`; model, docs, migration, and regeneration work happens outside it and is tracked separately

## Pros and Cons of the Options

### Explicit relation vocabulary on read model properties (chosen)

- Good, because every generator decision is stated in the model, satisfying the declared-not-guessed rule
- Good, because annotations inside the `schema` block are invisible to core ESDM validators, so the extension is spec-conformant today and upstreamable later
- Good, because property anchoring keeps commands, fixtures, and stories reading the same fields as before
- Bad, because a second source for the same edge (parent and child declarations) can disagree, requiring the pairing checks

### Derivation from cardinality and naming

- Good, because models stay shorter (one declaration could imply the other side)
- Bad, because it works only while one edge connects two models; multi-edge cases need grammar rules on property names, which had been declined for id fields and stays declined here
- Bad, because an implied binding cannot be validated for agreement, only defended after the fact

### First-class relationship elements

- Good, because edges become first-class and could hold their own metadata
- Bad, because a top-level `relationships` block fails `esdm lint` (core rejects unknown top-level keys), and a separate extension document breaks the property anchoring the generators are built on

### Do nothing

- Good, because zero migration effort
- Bad, because Ecto associations, JSON:API relationships, and multi-edge naming all stay hand-written, which is precisely the gap this decision closes

## More Information

- Sources consulted: Ecto associations guide (all four kinds, join schemas, cheatsheet), JSON:API v1.1 ("Keys that reference related resources (e.g. `author_id`) SHOULD NOT appear as attributes"), Commanded guides and `commanded_ecto_projections` docs, Julian May "Counterexamples regarding consistency in event-sourced solutions (Part 2)" (no FKs on projections; constrain upstream, let queries tolerate gaps), ESDM core schema and design principles (esdm.io), WarpDrive 5.9.1 (legacy mode requires `inverse`; `sourceKey` separates property name from wire name; Polaris collection fields not yet implemented)
- [INVESTIGATE: read the WarpDrive relationship RFCs (emberjs/rfcs, label T-ember-data, plus the rfcs/ directory in warp-drive-data/warp-drive) before any Polaris-mode output is planned]
- [INVESTIGATE: migration drift auditing (reconstruct effective table state from migration files and diff against the model) is deferred to a dedicated session]
- The singularization used by `_ids` command fields is the one remaining derived spelling, kept by agreement from the many-to-many set semantics
