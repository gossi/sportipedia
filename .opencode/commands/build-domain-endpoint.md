---
name: build-domain-endpoint
description: Build the web endpoint for exactly one domain operation (single-endpoint entry point; repairs, not fresh slices)
agent: builder
---

# Build Domain Endpoint: $1

Load the [domain-endpoint recipe](@recipes/domain-endpoint.recipe.md) and execute it.

Parameters:

- `${parameters.operation}` = `$1`
- `${parameters.spec_path}` = `$2` — optional

## Notes

Follows the same rules as `build-domain-feature`, scoped to one endpoint:

- One architect plan (`scope=endpoint`, decisions only), one implementer, one
  reviewer, up to 3 review attempts.
- No `find-domain-operation` step: the generators fail loudly on an unknown name.
- You run the gates and the commit yourself. The subagent ends its response with
  `FILES:`; commit exactly that list, never `git add -A`.
- Web actor only. The domain operation must already exist and be green — the
  controller calls exactly one function on the constituent's public API and never
  touches `Repo`, queries, the aggregate or the command struct.
- Pass the spec by **path**, never by pasted content.

The endpoint-specific decisions the plan must state: authorization plug and actor
set, success status (`200` for creates per the controller blueprint, not the
legacy `201`), which error atom maps to which status and through whom, and the
full route path with its verb.

`sportipedia_web/router.ex` is one shared file: concurrent slices will stomp each
other's scopes, and that is repaired by re-running the generators in `converge`,
not by hand-merging. Gate on the route list, not only on tests — the test harness
uses the compiled router, so a stomped scope can pass tests while the real route
table disagrees.
