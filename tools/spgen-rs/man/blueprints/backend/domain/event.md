---
generator: "mix sp.gen.event <event>"
blueprints:
  - SpGen.Blueprint.Event
  - SpGen.Blueprint.EventTest
module: "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Event.<Event>"
writes: [module, event test]
---

# Event

A fact that happened. Events are the unit of behaviour that the aggregate, the
projector and their tests are written against.

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the event and
  its data.

## What the generator does

`use TypedStruct`, `use ExConstructor`, `@derive Jason.Encoder`, and the payload
by what the event does (derived from the read model's projection rule, so
`--template` is usually omitted):

- **create** — every required field, `enforce: true` per field.
- **update** — `id` enforced, payload optional, plus `get_changes/1`, which
  returns only the non-nil changed fields without the id. That function is the
  projector's partial-update source.
- **delete** — `id` only.

Never `enforce: true` at struct level: optional fields have to stay omittable.

## Tests

The event owns the [event test](./event-test.md): `describe "Event"` with the
construction, enforced-field and JSON serialization cases. The `get_changes/1`
semantics are still manual ([Known gaps](../../README.md#known-gaps)).
