---
generator: "mix sp.gen.public_api <operation>"
blueprints:
  - SpGen.Blueprint.PublicAPI
  - SpGen.Blueprint.PublicAPITest
module: "Sportipedia.<Subdomain>.<Composite>.<DomainObject>"
writes: [module, operation test]
---

# Public API

The constituent's port: exactly one function per operation, nothing else.

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the command or
  query the function stands for.

## What the generator does

One function per operation, its `@spec` typed as `Architecture.public_api(…)`,
and the body by what the operation does:

- **create** — generate the UUID, `Map.put(params, "id", id)`, dispatch with
  `consistency: :strong`, return the projected read model.
- **update** — dispatch with the given id, return the read model.
- **delete** — dispatch, return `:ok`; no read model follows.
- **read** — the model's named query through `Repo.one/1`; `nil` →
  `{:error, :not_found}`. An `oneOf` id-or-slug parameter is realized **once**,
  in the query. The internal API is the port's after-dispatch `by_id` lookup for
  create and update.
- **collection** — `Repo.all` with `Sportipedia.Support.JSONAPI.QueryBuilder`.

Validation errors surface through `Sportipedia.Support.ErrorClassifier`: Vex runs
as commanded middleware, so there is no `try`/`rescue` and no param matching —
both would swallow the error the caller needs.

What stays out of the port by design: anything that belongs to the internal API,
and any function not named by the model.

## Tests

In the [operation test](./operation-test.md), under `describe "Public API"`:
success, `{:error, {:validation_failure, _}}` for commands, `:not_found` for a
read of an unknown id, the unknown-id and success cases for delete. The
successful read (seed, then read) and the update cases are manual
([Known gaps](../../README.md#known-gaps)).
