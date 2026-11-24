# Event Test

One test file per event: `test/…/<domain_object>/events/<event>_test.exs`. The
fact is the unit of behaviour, so everything that consumes the fact is tested
beside it — the event's own shape, the aggregate that folds it, the projector
that applies it.

## Generated

- `use Sportipedia.<Subdomain>TestCase`, `@moduletag :integration`, and the
  aliases for event, aggregate, projector and read model — each gated on the
  module it references.
- `describe "Event"` — construction with required fields, `struct!/2` raising for
  enforced fields, JSON serialization ([event](./event.md)).
- `describe "Aggregate"` — one `applies <event> to aggregate state` case per
  event of the constituent, asserting every event field lands in the state; a
  delete event asserts `nil`; an update event seeds the id
  ([aggregate](./aggregate.md)).
- `describe "Projector"` — `handle/2` with a full metadata map, then the row
  through `Repo.get`; an update or delete projection first projects the
  citizen's create event
  ([projector](./projector.md)).

Commands, handlers, policies and the public API are **not** here: they belong to
the [operation test](./operation-test.md).
