---
generator: "mix sp.gen.view <read-model>"
blueprints:
  - SpGen.Blueprint.View
  - SpGen.Blueprint.ViewTest
module: "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>View"
writes: [module, view test]
---

# View

The JSON:API representation of a read model: its type, its path, its attributes.

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the read model
  the endpoint returns.

## What the generator does

`use JSONAPI.View` with the singular JSON:API type, `path/0` from the
subdomain/composite/constituent route shape, and `fields/0` from the read model's
`schema` — `id` and the timestamps are excluded, they are not attributes. The
`@moduledoc` and the `@doc`s follow the model.

The view is the read model's face: a field that should not be public is removed
from the read model, not hidden here, and an attribute or `include` the model does
not express as a field starts there, not in the view.

## Tests

Its own file, `<domain_object>_view_test.exs`, generated with the view: `type/0`,
`fields/0`, `path/0` and a `render("show.json", …)` document assertion. Add an
assertion when you add a field the model states.
