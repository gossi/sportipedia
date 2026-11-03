# Blueprints

Blueprints are a vital part of architecture design for Sportipedia.

## Design Goals

- They are designed to ensure quality standards amongst the codebase
- They are designed so code changes are _cheap_ by following the same standards
  everywhere
- One function doing one thing but in different places shall give the same look
  for a _human_ to feel "at home"
- Coding agents thus must strictly follow them, to achieve the design goals
- Code may age, but blueprints are the source of truth
- Blueprints can drive refactorings, aged code can't

## Context for Using Blueprints

- [Read Architecture Documentation](../../../ARCHITECTURE.md)
- [Read Placeholder Naming Substitution](../naming-substitution.md)
- [Respect Coding Guidelines](../../coding-guidelines/README.md)

## Blueprint Structure

The blueprints follow a structure

1. Name (first heading)
2. Table with relevant metadata
3. (Prerequiste)
4. Implementation
5. Tests

_Prerequisite_ list things required to apply this blueprint.

_Implementation_ sections includes information to implement a particular
functionality. Blueprint + domain model is 99% the information that is
needed to implement the functionality. The last 1% is found in the specification
of a particular feature (this is known upfront).
As part of instructions, usually blueprints contain an implementation template
to scaffold the implementation. Even examples are there to represent common functionality.

_Tests_ have information what to use to write the tests for the functionality.
Usually this also includes _what_ and _how_ to test.

With both _implementation_ and _test_ given, this allows for
test-driven-development (tdd).

### Code Templates

- Code Templates give you a scaffolding, when creating the file from scratch
- They are templates, not strict guidelines
- Sorting functions in modules when they contain both queries and commands:
  1. All commands
  2. All queries

## Executable Blueprints (Code Generators)

Blueprints are progressively transferred to executable Elixir templates in
`tools/spgen` (`SpGen.Blueprint.*`), run through delegating mix tasks in
`services/api`:

```sh
mix sp.gen               # list all available generators
mix sp.gen.command <element> --template create
```

- The markdown here stays the design documentation; the executable transfer
  adds one pointer line per implemented blueprint.
- Blueprints define the file _contents_; the generators know the _layout_
  (canonical paths live with the generator, see `SpGen`).
- A generator family (`mix sp.gen.<family>`) runs one blueprint module per
  generated file: the citizen's module (e.g. `Blueprint.Aggregate`), its
  test file (`Blueprint.AggregateTest`) and any registration file
  (`Blueprint.CommandRouter`, `Blueprint.ProjectorSupervisor`,
  `Blueprint.WebRouter`).
- Generators resolve an ESDM element (`esdm:` reference, model file,
  `kind.name`, or bare name — matched against the kinds the
  generator produces), fill the placeholders per
  [naming substitution](../naming-substitution.md), and merge idempotently
  by append-only AST editing (`SpGen.Merge`): missing units
  (`use`/`alias`, function clauses, `field`/`validates`/`dispatch`/`project`
  entries, supervisor children, routes, `describe` blocks) are inserted as
  new nodes in the parsed file and the tree is printed back — existing code
  is never rewritten. `--check` reports drift without writing.
- **References defer, order never matters.** A unit that mentions another
  citizen (an event struct, a validator, the controller behind a route)
  only materializes while that citizen's file exists; otherwise it reports
  as `deferred` (exit 0) and the tree stays compilable. When a run creates
  a citizen, a merge-only closure pass re-applies the gated units of its
  constituent's neighborhood, so the referencing code back-fills itself —
  generating the event after the aggregate adds the aggregate's `apply/2`
  clause. Generation order is irrelevant: any sequence converges to the
  same code (proven by the reversed-chain test).
- `--template` selects the body template by what the operation does
  (`create | update | delete | read | collection`); default: derived from
  the domain model (the published event's projection effect, or the query
  result shape). Fixed-shape blueprints (e.g. command-handler) take none.
- The tool is an escript built on demand by the mix tasks
  (`SPGEN_NO_AUTOBUILD=1` opts out); recovery if the project tree itself is
  broken: run `tools/spgen/spgen <family> <element> [options]` directly.

Implemented: [Command](backend/domain/command.md),
[Event](backend/domain/event.md),
[Command Handler](backend/domain/command-handler.md),
[Aggregate](backend/domain/aggregate.md),
[Read Model](backend/domain/read-model.md),
[Projector](backend/domain/projector.md),
[Policy](backend/domain/policy.md),
[Public API](backend/domain/public-api.md),
[Internal API](backend/domain/internal-api.md),
[Validator](backend/domain/validator.md),
[Query](backend/domain/query.md),
[View](backend/domain/view.md),
[Schema](backend/domain/schema.md),
[Controller](backend/domain/controller.md),
[Endpoint Test](backend/web/endpoint-test.md),
[Bruno](backend/web/bruno.md),
[Operation Test](backend/domain/operation-test.md) (shared describe mechanism).

Not executable: Migration — deliberately stays with `mix ecto.gen.migration`.

## Available Blueprints

Here: [/docs/architecture/blueprints/](../../../docs/architecture/blueprints/)
