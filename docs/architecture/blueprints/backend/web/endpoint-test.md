---
test_file: endpoint test
module: "SportipediaWeb.<Subdomain>.<Composite>.<DomainObject>.<Operation>EndpointTest"
contributors:
  - "mix sp.gen.controller <operation>"
---

# Endpoint Test

The HTTP view of one operation: request in, status and JSON:API document out.
Contributed by the [controller](./controller.md) generator into
`test/sportipedia_web/…/<domain_object>/operations/<operation>_endpoint_test.exs`.

## Prerequisite

- The controller, route and schemas have been generated.

## Harness

`use SportipediaWeb.ConnCase` gives the `<Subdomain>.Repo` sandbox plus
`Phoenix.ConnTest` macros (`build_conn`, `post`, `get`, `json_response`).
`SportipediaWeb.RequestHelpers` is imported by the generated file:

| Helper | Purpose |
| --- | --- |
| `authenticate_conn(conn, user \\ %{id: UUID.uuid4()})` | sets `conn.assigns.user` for the Bodyguard policy |
| `api_conn(conn)` | sets `Content-Type: application/vnd.api+json` |
| `jsonapi_body(type, attrs)` | `%{"data" => %{"type" => type, "attributes" => attrs}}` |
| `jsonapi_body(type, attrs, id)` | same, with `"id"` inside `data` |
| `jsonapi_id(response)` / `jsonapi_type(response)` | `data.id` / `data.type` |
| `jsonapi_attrs(response)` / `jsonapi_attr(response, field)` | `data.attributes` / one attribute |

Requests always go out as `api_conn()` + `Jason.encode!(jsonapi_body(…))`. The
`JSONAPI.Deserializer` plug flattens `data.id` and `data.attributes.*` into
`conn.params`, so an id sent in `data.id` arrives as `conn.params["id"]`.

## Status contract

`json_response(conn, expected_status)` raises when the status differs — do not
wrap it in another `assert`.

| Code | Meaning |
| --- | --- |
| `200` | successful create, read, update or collection |
| `204` | successful delete or archive |
| `403` | unauthenticated — `FallbackController` answers `{:error, :unauthorized}` with 403 |
| `404` | unknown resource |
| `422` | validation failure |
| — | invalid query parameter (e.g. `?sort=id` outside the read's whitelist) — **no row yet**: `JSONAPI` raises `JSONAPI.Exceptions.InvalidQuery`, no `rescue`/`handle_exception` exists in `sportipedia_web`, and the `:api` pipeline runs no request-validation plug, so production answers `500`. A `400` handler is a [follow-up](../../../../follow-ups.md#invalid-query-parameters-answer-400); until it lands, a test that pins the refusal pins the raise (`assert_raise JSONAPI.Exceptions.InvalidQuery`), never a status the endpoint does not owe |

`200` for a create is what this blueprint and the generator produce. The legacy
equipment and instrument controllers answer `201` — see the finding in
[controller](./controller.md#finding-200-or-201-for-a-create-endpoint) before
copying either.

Unauthenticated means: send the request **without** `authenticate_conn`. The
`:api` Guardian pipeline runs with `allow_blank: true`, so a missing token is not
an error — the policy is what denies.

## Generated

`describe "<VERB> <path>"` per operation, with the happy path (including the
create-then-act seeding an update or delete needs), the 403 case for commands,
and the 404 case for delete and read.

## Learnings

- A test name is the status it asserts ("returns 403 when unauthenticated"),
  because that is the contract the endpoint owes the client.
- The status you assert must come from the blueprint, not from the nearest old
  controller. `200` versus `201` on create is exactly the kind of "pattern" that
  hand-copied tests spread.
