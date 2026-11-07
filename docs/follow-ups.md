# Follow-ups

Work the reviews and slices decided *not* to do inside their slice boundary,
recorded so nothing is inherited silently. Each entry names its source.

## Web

### Invalid query parameters answer 400

A query parameter a read refuses — e.g. `?sort=id` outside the list's whitelist —
raises `JSONAPI.Exceptions.InvalidQuery`. No `rescue`/`handle_exception` exists in
`sportipedia_web`, the `:api` pipeline runs no request-validation plug, and the
affected operations document only `ok:`. In production the refusal is a **500** on
an endpoint whose contract says the field is "refused, not ignored". Pre-existing
(`apparatus` raises identically for `sort=slug`). Open: a `400` handler in
`SportipediaWeb`, error responses on the list operations, and an `endpoint-test.md`
status-table row filled in. Source: position-slice review **Q7** (2026-11-07).

### Equipment create endpoints move to `200`

Decided (position-slice review **F9**): `200` is the standard — the blueprint and
`SpGen.Blueprint.Controller` emit `ok:`. `catalog/equipment/apparatus` and
`instrument` still answer `201`; move both controllers, their endpoint tests and
their Bruno files together. Source: position-slice review **F9(2)** (2026-11-07).

### Log-noise and PII: `:introspect` payload logging

`services/api/lib/sportipedia_web/router.ex:34-45` logs every catalog request with
`IO.puts` of the full payload, and `system/fallback_controller.ex:25` `IO.inspect`s
unknown errors. Log noise today, a leak tomorrow. Source: position-slice review
**F16** (2026-11-07), reported by three workers.

## Auth citizen

### The admin claim's contract across `Sportipedia.Auth`

The admin actor rests on `user.role == "admin"` (a string) arriving via better-auth's
jwt plugin default payload (`services/auth` registers `admin()` + `jwt()` with no
`definePayload`). Two in-tree documents contradict it: `Sportipedia.Auth.Guardian.token()`
omits `role` entirely, and `Sportipedia.Auth.User` types role as
`:guest | :user | :admin` (atoms) while `Roles.is_admin?/1` compares to a string.
Fix the citizen's declared contract; note that users predating the admin plugin may
carry `role = NULL`. Source: position-slice review **F14** (2026-11-07).

## spgen

### `SpGen.Blueprint.Schema` dedupes alias/require units

Generated schema files carry doubled `alias`/`require` lines (the widget snapshot
shows it; position's `position_response.ex`, `position_collection_response.ex` and
`catalog_position_request.ex` too). The alias/require units must dedupe by target.
Source: position-slice review **F13** (2026-11-07).

### The validates needle learns per-field clauses

Since `SpGen.Invariant.FieldRule` registers a multi-field rule on every named field
(review **F6**), a rule module whose second field calls a second clause
(`EquipmentExists.validate_instrument/2`) reports `Outdated` forever: the needle is
`&<Module>.validate/2`. Either teach `validates_needle/1` to accept any function of
the module, or give descriptors a clause name. Until then such lines are registered
deviations per constituent. Source: position-slice review **F6** consequence,
deviation **D8** (2026-11-07).

## Domain model / specs

### `result.meta.total` on `query.list-positions`

The model's `result` is a plain array and no consumer needs page counts yet; when
one appears, add `result.meta.total` to `query.list-positions.esdm.yaml` and the
collection response's `meta`. Source: position-slice review **Q6(b)** (2026-11-07).

### Query constraints in `Unresolved rules`

`validator.md`'s unresolved-rule wording assumes command elements; a *query*
constraint (`paginate` on `list-positions`) cannot become a validator yet showed up
under `Unresolved rules`. Scope that sentence to commands or keep query constraints
out of `Context.unresolved`. Source: position-slice review **Q6(a)** (2026-11-07).

## Architecture types

### `Architecture.public_api` validation vocabulary

`Sportipedia.Architecture.public_api` types validation failures as
`%{String.t() => [String.t()]}`, while the validators emit atom keys and atoms
(`:slug_exists`, `:equipment_not_found`, `:at_most_one_equipment`). Widen the type or
state the vocabulary; the position slice builds on the atom vocabulary.
Source: position-slice review **F15** (2026-11-07).

## Port specs

### `list_positions/1` error arm

The port's `@spec` admits `{:error, …}` while the controller's `case` handles only
`{:ok, data}` — an error from the port becomes a `CaseError`/500. Narrow the `@spec`
to `{:ok, [t]}` or add the error arm. Source: position-slice review **Q6** (2026-11-07).

## Agentic process

### Persist the design artifact inside the slice pathspec

The design artifact lives only in the conversation, so its register and deviation IDs
are unauditable after the run; its file list also under-reported (`F10`). On re-issue:
write the artifact to a file the commit carries, and §4 may cite deviation IDs only as
defined in §5 (a slug-casing pin is always D2). Source: position-slice review
**F12(b)** process finding (2026-11-07).
