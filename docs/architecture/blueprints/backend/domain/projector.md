---
generator: "mix sp.gen.projector <event>"
blueprints:
  - SpGen.Blueprint.Projector
  - SpGen.Blueprint.ProjectorSupervisor
  - SpGen.Blueprint.ProjectorTest
module: "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Projector"
writes: [module, supervisor child, event test]
---

# Projector

Applies a fact to the read model(s). One clause per projected event.

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) has a `projection` on
  the read model naming this event.

## What the generator does

`use Commanded.Projections.Ecto` with `application`, `repo`, the projection
`name` (`<composite>.<domain_object>_projection`), `schema_prefix` and
`consistency: :strong`; the `project/3` clause; the child in the nearest
supervisor (composite first, else subdomain — created when missing); and the
event test's `describe "Projector"`.

The clause body is **derived, not chosen**: `SpGen.Context` reads the read
model's projection rule (`Esdm.projection_effect/1`) and emits insert,
update-from-`get_changes/1`, or delete — a missing row is a no-op for update and
delete. `--template` is validated at the CLI; the body follows the model.

## Left to you

- **Check the clause against the rule.** A projection rule whose prose states no
  effect falls back to create; if the model says otherwise, say so in the rule.
- **Anything that is not row CRUD** — a computed column, a second read model, a
  side effect — is spec logic, added inside the generated clause.

## Tests

In the [event test](./event-test.md), under `describe "Projector"`: the
generated case calls `handle/2` with a full metadata map —
`handler_name` equals the projector's `name:` option, `event_number` is a unique
non-negative integer — and asserts the row after an update or delete projection
by first projecting the citizen's create event. Its idempotency and error cases
are still manual ([Known gaps](../../README.md#known-gaps)).
