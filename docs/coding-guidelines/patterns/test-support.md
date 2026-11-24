# Test Support

A test's scaffolding — sandbox, request building, fixture data, seeding —
is already built and owned by the model. This page is about reaching for it
instead of writing your own.

## The support layer exists; do not reinvent it per test

### DO NOT

Hand-roll what the support layer already gives: `Repo.checkout` in a setup
block, string-built JSON:API envelopes, a local `defp authed_conn` that
invents its own user shape, a `Map.take` chain to read `data.attributes`
out of a response.

### DO INSTEAD

Start every test file from the case that owns its sandbox and imports:

| Test | Open with |
| --- | --- |
| endpoint (web) | `use SportipediaWeb.ConnCase` — Repo sandbox, `Phoenix.ConnTest`, `SportipediaWeb.RequestHelpers` |
| domain (operation/event) | `use Sportipedia.CatalogTestCase` — `@moduletag :integration` sandbox, `errors_on/1` |

Requests go out exactly one way: `api_conn()` around
`Jason.encode!(jsonapi_body(type, attrs))` — with the `id` inside `data`
when the operation addresses one. The `JSONAPI.Deserializer` plug then
delivers `conn.params["id"]` and the flattened attributes; an endpoint test
that hand-assembles `%{"data" => ...}` without the helpers is testing a
shape the deserializer was never given. Read responses through
`jsonapi_id/jsonapi_type/jsonapi_attrs/jsonapi_attr`, authenticate with
`authenticate_conn` (and prove the 403 by *omitting* it), never by poking
`conn.assigns` yourself.

## Data comes from fixtures; state comes from factories

Fixtures are the model's declared examples, materialized by
`sparch man test_support` into `test/support/.../fixtures/<domain_object>s.ex`:
one zero-arity function per example, ids as `UUID.uuid5(:dns, "<key>")` —
one mnemonic names one thing in every environment forever.

### DO NOT

Invent attribute maps inline (`%{title: "sample-title", …}`), or generate an
id with `UUID.uuid4()` for data another citizen must refer to.

### DO INSTEAD

Call the generated fixture — `ApparatusFixtures.parallel_bars()` — and seed
through the composite factory: `new_<domain_object>/1` takes the fixture
struct *or* a plain map, `new_<domain_object>s/1` persists a collection and
**raises** with the changeset errors on failure, because a half-seeded world
is the most confusing failure mode a test can have. Need a fact the fixture
doesn't carry? Declare the example in the read model and regenerate; a
hand-written map is invisible to every other consumer of the same mnemonic.
Which one the case needs — fixture row or command dispatch — is
[test data](test-data.md).
