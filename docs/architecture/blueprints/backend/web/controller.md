---
generator: "mix sp.gen.controller <operation>"
blueprints:
  - SpGen.Blueprint.Controller
  - SpGen.Blueprint.ControllerTest
  - SpGen.Blueprint.WebRouter
module: "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Controller"
writes: [module, endpoint test, web route]
---

# Controller

The HTTP adapter for one operation: parse the request, call the
[public API](../domain/public-api.md), render the response. No domain logic — the
public API is the only thing a controller may call.

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the command or
  query.
- The public API function, the [view](./view.md) and the
  [schemas](./schema.md) exist — until they do, the action defers and the run
  reports `skipped: spgen public_api`, `skipped: spgen schema`, …
- `services/api/lib/sportipedia_web/router.ex` exists. It is operator-owned and
  merge-only: a missing router is a `Failed`, not something the generator
  invents.

## What the generator does

- The controller module with `use SportipediaWeb, :controller`,
  `use OpenApiSpex.ControllerSpecs`, the `Bodyguard.Plug.Authorize` plug on the
  constituent's policy with `SportipediaWeb.System.FallbackController`, and
  `tags ["<composite>"]`.
- One action per operation, `operation :<op>` with summary, request body and
  responses (including the shared `not_found` / `unprocessable_entity` /
  `unauthorized` / `forbidden` references), a `@spec`, and the action body for
  the effect: create, update and read render the resource as `ok:`, a collection
  renders `index.json`, delete and archive send `no_content` (`204`).
- For a collection query, the `JSONAPI.QueryParser` plug with `filter:` and
  `sort:` from the model's parameters, gated on the view.
- The route in the web router's scope chain (`/<subdomain>` → `/<composite>` →
  `/<domain-object>s`), materializing missing scope levels. Only GET for queries
  and POST for commands — every write is a command endpoint, so there is no
  PATCH/PUT/DELETE route.

`@moduledoc` and `@doc` come from the model; OpenAPI summaries fall back to a
`TODO:` marker.

The boundary is absolute: a controller calls the
[public API](../domain/public-api.md) and nothing else — never `Repo`, never a
query, never an aggregate. A response the operation does not imply starts in the
domain model, not in this file.

## Tests

The endpoint test is contributed by this same run; see
[Endpoint Test](./endpoint-test.md).

## Learnings

### Finding: `200` or `201` for a create endpoint

#### DO NOT

Copy `put_status(:created)` and a `created:` response from the existing
equipment controllers and call it the standard.

#### DO INSTEAD

`200` is the standard: this blueprint and `SpGen.Blueprint.Controller` answer
`ok:` (`200`) for a create, and a generated controller and its generated test
agree on it. `catalog/equipment/apparatus` and `instrument` answer `201` —
legacy, decided against, not a pattern to copy or to re-litigate per slice;
moving them is a
[follow-up](../../../../follow-ups.md#equipment-create-endpoints-move-to-200).
