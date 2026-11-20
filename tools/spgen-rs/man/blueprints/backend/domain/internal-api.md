---
generator: "mix sp.gen.internal_api <element>"
owner: "also reached as a dependency of every validator a command generates"
blueprints:
  - SpGen.Blueprint.InternalAPI
  - SpGen.Blueprint.LookupQuery
module: "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Internal"
writes: [module]
---

# Internal API

Data access inside one constituent — for its public API, its validators and its
tests. Never across a constituent or composite boundary.

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the read model
  and, for each lookup accessor, the invariant that makes the field addressable.

## What the generator does

`<domain_object>_by_id/1` through `Repo`, and one accessor per unique-field
invariant (`<domain_object>_by_slug/1`, lowercasing the value and delegating to
the lookup query). It is reached two ways: as its own generator, and as the
dependency of every validator a command generates — together with the read model
it reads and the `Queries.<…>` module its accessor calls, so a generated
accessor never points at a module that does not exist.

What stays out of it by design: technical implementation that belongs elsewhere
(a query, a validator) and anything another constituent has to reach — that goes
through the [public API](./public-api.md). An accessor the model does not imply
(a join, a read across several read models) is added by hand, together with the
query it delegates to, and only for a caller that justifies it.

## Tests

No test file of its own: the internal API is exercised through the
[command](./command.md) validators and the
[public API](./public-api.md) in the
[operation test](./operation-test.md).
