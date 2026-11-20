---
generator: "mix sp.gen.bruno <operation>"
blueprints:
  - SpGen.Blueprint.Bruno
  - SpGen.Blueprint.BrunoFolder
writes: [bruno]
---

# Bruno

Runnable request documentation for one endpoint, in the Bruno collection at the
repo root. Not a test: a thing you can click while developing the operation.

## Prerequisite

- The operation exists in the [Domain Model](../../../../domain-model/README.md);
  the controller and route are generated, so the path and verb are real.

## What the generator does

One file per operation at
`bruno/<Subdomain>/<Composite>/<Constituent>/<Operation Title>.yml`, title-cased
like the rest of the collection, plus the constituent's `folder.yml` beside the
first request it holds.

- Verb by element kind: POST for a command, GET for a query — the same rule the
  controller follows.
- URL against `{{apiUrl}}`; collection variables live in `bruno/environments/`.
- A JSON:API body mirroring the operation's data: `create` carries attributes
  only (the id is generated), `update` and `delete` address the row by `id`.
- `examples:` generated from the domain model's feature scenarios.
- `seq:` orders commands before queries, so assignment order matches the run
  order — run the command generators first.
- Docs artifacts are **create-only**: an existing `.yml` is never rewritten, so
  hand-tuned headers, saved responses and extra examples survive every run. An
  API change is therefore not propagated — when the operation's shape changes,
  update the file (or delete it and regenerate). See
  [Ownership](../../README.md#ownership).

## Tests

None. Bruno files are documentation, not code under test — the endpoint they
describe is tested in the [endpoint test](./endpoint-test.md).
