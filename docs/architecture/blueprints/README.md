# Blueprints

Blueprints are the design contract for the code of a Sportipedia citizen, and
the source of truth for what a coding agent must not improvise.

## Design Goals

- They ensure quality standards across the codebase.
- They keep code changes cheap: the same standards everywhere.
- One function doing one thing looks the same in every place.
- Coding agents follow them; they do not improvise.
- Code may age; blueprints are the source of truth.
- Blueprints drive refactorings; aged code cannot.

## What a blueprint is now

spgen owns **shape**. This markdown owns **intent, residual work and tests**.

- The executable side is `SpGen.Blueprint.*`, reached through `mix sp.gen.*`.
- The design side is this file: why the artifact exists, what the domain model
  must state, what is left to the operator, and what to test.
- A blueprint never repeats generated code. If a shape matters, it already lives
  in the generator; a code template in markdown is drift waiting to happen.

## Frontmatter

Every generated artifact starts its document with machine-readable frontmatter.
It replaces the old “Implemented as an executable blueprint” quote.

```yaml
---
generator: "mix sp.gen.projector <event>"
blueprints:
  - SpGen.Blueprint.Projector
  - SpGen.Blueprint.ProjectorSupervisor
  - SpGen.Blueprint.ProjectorTest
module: "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<DomainObject>Projector"
writes: [projector, supervisor child, event test]
---
```

| Key | Meaning |
| --- | --- |
| `generator` | The command template an operator runs, or `none` |
| `blueprints` | The executable modules behind it — every one must exist |
| `module` | Dotted module name or template (never a file path) |
| `writes` | Roles only: `module`, `test`, `operation test`, `event test`, `endpoint test`, `view test`, `schema test`, `commanded router`, `commanded application`, `supervisor child`, `web route`, `bruno`, `migration` |
| `test_file` | For test-container documents: `operation test`, `event test`, `endpoint test`, `view test`, `schema test` |
| `contributors` | The generator commands that write into a shared test file |
| `invariant` / `pattern` | For `examples/*.md`: the rule family and the module realizing it |
| `owner` | For `generator: none`: who owns the artifact instead |

Roles, not paths: file layout belongs to the generators, and the run report
names the files it touched.

## Body sections

In this order, and nothing else:

1. `## Prerequisite` — what the domain model must contain.
2. `## What the generator does` — the emitted roles and the rules behind them, in
   prose. Never code: a shape that matters lives in the executable blueprint.
   A test container writes this as `## Generated` instead: which `describe`
   blocks land here, and from which generator.
3. `## Left to you` — the work spgen does not do. **Omit the section entirely
   when nothing remains**: a blueprint without it leaves the artifact finished,
   and the absence is the statement.
4. `## Tests` — the test document this artifact lives in, what the generator
   already asserts, and what remains.
5. `## Examples` / `## Learnings` — only where a rule needs a worked instance or
   a review finding has to outlive the pull request.

## Residual work

Whatever a blueprint does leave to you is one of three kinds, and each has one
place where it is stated:

- **Named by the run** — `Outdated` (a line that lacks a part the model now
  states) and `Unresolved rules` (a rule no invariant pattern realizes). The
  report says what to add; a blueprint never restates the procedure.
- **Decided by the feature spec** (`docs/specs/`) — deep handler behaviour, query
  filters, non-CRUD projections, policy beyond the actors, spec-specific
  assertions.
- **Operator wiring** — see [Ownership](#ownership): migrations, the subdomain
  supervisor start, `Repo` and test case, Bruno updates.

Two rules hold everywhere and are not repeated per blueprint:

- A check the model does not state goes **into the model first** — not into a
  hand-edited command, policy or controller.
- Never hand-write a generator unit (`use`, `import`, alias, the module or a
  `describe` skeleton): a hand-made duplicate is something the merge cannot
  reach. Append what the unit does not cover — its body, its assertions.

Documents that are not generated artifacts drop out of that shape on purpose:
[validator](backend/domain/validator.md) documents the patterns,
the [invariant examples](backend/domain/examples/unique-slug.md) state a contract,
and [migration](backend/domain/migration.md) is operator work. Their headings
follow their own argument — still no code template.

## Context for Using Blueprints

- [Read Architecture Documentation](../../../ARCHITECTURE.md)
- [Read Placeholder Naming Substitution](../naming-substitution.md)
- [Respect Coding Guidelines](../../coding-guidelines/README.md)
- [Respect Code Access Policy](../../../.opencode/code-access-policy.md) — the
  tool reads code for deltas; agents read documentation.

## Using the generators

### Listing and addressing

```sh
mix sp.gen                          # generators by actor, in run order
mix sp.gen.command catalog-apparatus
mix sp.gen.event event.apparatus-cataloged
mix sp.gen.aggregate esdm:domain=sport/bounded-context=sport/aggregate=apparatus
```

An element is an `esdm:` reference, a `*.esdm.yaml` path, `kind.name`, or a bare
name resolved among the kinds that generator produces. When a bare name is
ambiguous, the error prints the `esdm:` references that disambiguate it.

### Templates

`--template` is optional for `command`, `event`, `projector`, `public_api`,
`schema` and `controller`: the operation is derived from the domain model. Omit
it unless you are overriding a model that cannot state the effect. Fixed-shape
generators take no template and reject one.

### Prose slots

`@moduledoc`, `@doc`, OpenAPI summaries and descriptions come from the model's
`description`. Where the model is silent the generator writes a stable
`TODO: <what the slot asks>` marker: it is present on the first run, never
duplicated on later ones, and filling it is operator work — usually a better
domain model.

### Order

Order never matters: a reference to a citizen that does not exist yet defers,
and the closure pass of the run that creates it back-fills. The listing is the
known-good sequence:

`read_model → event → aggregate → query → internal_api → command →
command_handler → projector → policy → public_api`, then
`view → schema → controller → bruno`.

A generator also plans the blueprints its code calls — a validator with the
internal API it uses and the lookup query and read model behind that accessor —
so the explicit list is shorter than the number of files written.

### Reading the report

- `Created` — new file.
- `Updated` — missing units appended to an existing file.
- `Ignored` — nothing missing. A line ending in `skipped: spgen <x>` is a
  deferred unit: run `<x>`. A deferral is guidance, not an error.
- `Outdated` — a line exists but does not carry everything the model states now
  (today: a `validates` line missing a rule). The merge never rewrites a line,
  so the gap is listed with the exact part to add, and one line per file is kept
  so nothing can shadow it.
- `Unresolved rules` — a rule the model states that no `SpGen.Invariant` pattern
  realizes. Nothing is generated for it; the run names it under the element it
  came from so the operator can implement it (see
  [validator](backend/domain/validator.md)).
- `Blocked` — a missing unit has no home in the target file; fix the file or
  report a documentation gap.
- `Failed` — unparsable file, unexpected module, or a missing registration host.

Exit status is `0` unless something is `Blocked` or `Failed`. `--check` writes
nothing and prints the same report in future tense; it is a report, not a CI
gate.

### Idempotence and recovery

Re-running a generator over generated code reports `Ignored`. The merge is
append-only: existing lines are never rewritten. If the project does not
compile, the mix tasks still work (the tool is a path dependency of the API);
as a recovery hatch run the binary directly:

```sh
tools/spgen/spgen <generator> <element> [options]
```

`SPGEN_NO_AUTOBUILD=1` stops the tasks from rebuilding it.

## Building one operation

Command:

```sh
mix sp.gen.read_model <read-model>
mix sp.gen.event <event>                # each published event
mix sp.gen.aggregate <aggregate>
mix sp.gen.command <operation>          # pulls validators, internal API, lookup queries
mix sp.gen.command_handler <operation>
mix sp.gen.projector <event>            # each projected event
mix sp.gen.policy <operation>
mix sp.gen.public_api <operation>
```

Query:

```sh
mix sp.gen.read_model <read-model>
mix sp.gen.query <query>
mix sp.gen.policy <query>
mix sp.gen.public_api <query>
```

## Building one endpoint

```sh
mix sp.gen.view <read-model>
mix sp.gen.schema <operation>
mix sp.gen.controller <operation>       # action, endpoint test, web route
mix sp.gen.bruno <operation>
```

## Test files

| Test file | Contributors |
| --- | --- |
| `operations/<operation>_test.exs` | `command`, `command_handler`, `policy`, `public_api`, `query` |
| `events/<event>_test.exs` | `event`, `aggregate`, `projector` |
| `operations/<operation>_endpoint_test.exs` | `controller` |
| `<domain_object>_view_test.exs` | `view` |
| `schemas/*_test.exs` | `schema` |

See [Operation Test](backend/domain/operation-test.md),
[Event Test](backend/domain/event-test.md) and
[Endpoint Test](backend/web/endpoint-test.md). A test file appears with the
first contributor that has a test to write — never as an empty module.

## Ownership

| Thing | Owner |
| --- | --- |
| Citizen modules, their tests, registrations | spgen |
| Validators, internal API, lookup queries | spgen, as a dependency of the caller |
| Commanded router, commanded application, subdomain supervisor skeleton | spgen, created when the composite lacks one |
| Web router | operator; merge-only and must exist, or the run fails |
| Starting the subdomain supervisor from the root application, `Repo`, subdomain test case | operator, per subdomain |
| Migrations | `mix ecto.gen.migration` |
| Business logic: deep handler rules, query filters, policy beyond `actors`, spec-specific assertions | operator, from the feature spec |
| Bruno updates after an API change | operator — Bruno is create-only |

## Definition of done

- The run reports no `Blocked` and no `Failed`, and the expected files appear
  under `Created`/`Updated`; a second run reports `Ignored`.
- Every `skipped: spgen <x>` has been resolved by running `<x>`, or is an
  intentional deferral that is named.
- No unexplained `TODO` or `raise "TODO …"` is left in a generated file.
- Every `Outdated` line has been completed by hand — the merge never rewrites a
  line, so what is missing is listed with the exact part to add.
- Every `Unresolved rules` entry has either been implemented (validator **and**
  the command's `validates … by:` line) or is deliberately not enforced.
- Tests for every touched file pass.
- `mix format` and `mix compile --warnings-as-errors` are clean.

## Review checklist

- Does the run report match the plan — files and units?
- Is the diff append-only, with no existing lines rewritten?
- Does the spec's behaviour live where the generator left the anchor, and
  nowhere else?
- Do the tests assert behaviour through public interfaces, not structure?
- Are migrations, the supervisor start and the test case wired for the new
  constituent?

## Known gaps

What the documents above promise but spgen does not yet do — stated here so
nobody rediscovers them as "mysterious missing code":

- **The projection effect is prose.** `Esdm.projection_effect/1` matches keywords
  in the read model's projection `rule`. A rule that matches none of them
  silently generates a create clause.
- **`--template` on `projector`** is validated but the clause body follows the
  model regardless — the override has no effect there.
- **Create endpoints**: this blueprint and `SpGen.Blueprint.Controller` answer
  `200`; the equipment and instrument controllers answer `201`.
- **Test cases still manual**, each named where it belongs: the command's
  invariant cases (duplicate value, and for an edit the ownership cases), the
  handler's field-by-field mapping, an update event's `get_changes/1`, the
  projector's idempotency and error cases, an admin or param-dependent policy
  case, a successful read, the update cases of the public API, and endpoint
  `422`.

## Blueprints

Domain: [Aggregate](backend/domain/aggregate.md),
[Command](backend/domain/command.md),
[Command Handler](backend/domain/command-handler.md),
[Event](backend/domain/event.md),
[Read Model](backend/domain/read-model.md),
[Projector](backend/domain/projector.md),
[Policy](backend/domain/policy.md),
[Public API](backend/domain/public-api.md),
[Internal API](backend/domain/internal-api.md),
[Query](backend/domain/query.md),
[Validator](backend/domain/validator.md),
[Operation Test](backend/domain/operation-test.md),
[Event Test](backend/domain/event-test.md).

Web: [View](backend/web/view.md),
[Schema](backend/web/schema.md),
[Controller](backend/web/controller.md),
[Endpoint Test](backend/web/endpoint-test.md),
[Bruno](backend/web/bruno.md).

Invariants: [unique-slug](backend/domain/examples/unique-slug.md),
[domain-object-exists](backend/domain/examples/domain-object-exists.md).

Not executable: [Migration](backend/domain/migration.md) — deliberately stays
with `mix ecto.gen.migration`.
