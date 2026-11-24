# Status Codes

What an endpoint test may assert, and where that answer must come from. What
the generator produces is authoritative in `sparch man controller` — create,
update and read answer `ok:` (200), delete and archive `no_content` (204).

## The status you assert comes from the matrix

### DO NOT

Assert a status because the nearest old endpoint answers it. Hand-copied
tests spread `200` versus `201` on create exactly like hand-copied
controllers do.

### DO INSTEAD

The endpoint test's asserted status comes from this matrix, which is also
what the generator emits:

| Operation | Statuses |
| --- | --- |
| create | 200 / 422 / 403 |
| delete | 204 / 404 / 403 |
| read | 200 / 404 |
| collection | 200 |

A generated controller, its responses and its generated test that disagree
is a bug in one of them. A test name states the status it asserts
([test naming](test-naming.md)).
