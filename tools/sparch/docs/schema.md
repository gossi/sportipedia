# ESDM Extensions

sparch reads the plain ESDM core schema plus three extension keywords. They
carry the decisions a generator must not guess. Like all annotations they are
documentation to JSON Schema validators — sparch is the only reader, and none
of them appear in the ESDM core schema.

## Declared operations — `metadata.annotations`

### `spgen.operation` on a command

The operation the command performs:

```yaml
metadata:
  annotations:
    spgen.operation: update
```

Values: `create`, `update`, `delete`, `none`. Missing or outside that set,
generation refuses — a command never lets the generator infer what it does.
The value drives everything downstream: template choice, state fold, payload
shape. `none` marks an audit fact: it changes no state.

### `spgen.operation` on a query

How the query reads. Values: `read` (one resource) or `collection` (a list).
A collection read generates its body in full; any other query leaves its body
to the feature spec.

### `spgen.operation.<event>` on a read model

The read model is the ledger of its events. One key per event, naming the
effect the projector applies:

```yaml
metadata:
  annotations:
    spgen.operation.widget-created: create
    spgen.operation.widget-edited: update
    spgen.operation.widget-archived: delete
```

Values are the same four as on commands. Every event of the aggregate must
appear — a missing one is reported as a gap, and its projector clause and
`apply/2` fold are skipped.

Placement is checked both ways: bare `spgen.operation` belongs on commands
and queries only; the per-event form belongs on read models only. An
`spgen.operation.*` key on an event or anywhere else is a finding.

## Relations — `x-esdm-relation`

On a schema property, declares that the field is the identifier of a
relationship:

```yaml
properties:
  apparatusId:
    type: string
    format: uuid
    x-esdm-relation:
      to: apparatus
      cardinality: many
      inverse: positions
```

- `to` — the read-model name the relation points at. The TS type and name
  come from `to`, never from stripping an `Id` suffix.
- `cardinality` — `one` means this instance holds one (the n:1 side); `many`
  means it holds a collection.
- `inverse` — optional, the property name on the far side. Absent means the
  relation is unidirectional.

The FE always speaks resolved domain objects (`apparatus?: Apparatus`),
never raw ids.

## Standard keywords, given a job

`readOnly` and `writeOnly` are plain JSON Schema annotations; sparch fixes
their reading:

- `readOnly: true` — owned by the server. It stays on the interface (it
  arrives on the wire) but is never writable: no command input, no `XFields`
  member, no fixture entry to edit.
- `writeOnly: true` — never comes back. The FE ignores it entirely: no
  interface property, no schema field, no fixture, no story.
