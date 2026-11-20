# Aggregate

The stream of events for one domain object, folded into state.

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
