---
generator: "mix sp.gen.aggregate <element>"
blueprints:
  - SpGen.Blueprint.Aggregate
  - SpGen.Blueprint.AggregateTest
module: "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Aggregate"
writes: [module, event test]
---

# Aggregate

The stream of events for one domain object, folded into state.

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the aggregate
  and the events that change it.

The generator accepts an `aggregate`, `command` or `event` element and always
resolves the aggregate's own element, so `mix sp.gen.aggregate position` and
`mix sp.gen.aggregate catalog-position` write the same file.

## What the generator does

- `typedstruct` state from the aggregate's `state`.
- One `apply/2` clause per event of the constituent, pattern-matching aggregate
  and event: a create rebuilds the struct from the event's fields, an update
  merges `Event.get_changes/1`, a delete returns `nil`.
- The `@moduledoc`, which stays a `TODO:` marker until the model describes the
  aggregate.

## Tests

The aggregate's `describe "Aggregate"` lives in the
[event test](./event-test.md), one `applies <event> to aggregate state` case per
event: create starts from an empty struct, update seeds the id, delete asserts
`nil`. Field-by-field assertions follow the event's data.
