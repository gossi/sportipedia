---
generator: "mix sp.gen.command_handler <operation>"
blueprints:
  - SpGen.Blueprint.CommandHandler
  - SpGen.Blueprint.CommandHandlerTest
module: "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>Handler"
writes: [module, operation test]
---

# Command Handler

Turns one command into the event(s) that fact happened.

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the command
  and what it `publishes`.

The shape is identical for every operation — input command, output events — so
this generator is fixed and takes no `--template`.

## What the generator does

- The `@behaviour Commanded.Commands.Handler`, the aliases for command, aggregate
  and event, the `@doc`, the `@spec` (`event.t() | [event.t()]`) and the
  `handle/2` head matching `%Aggregate{}` and `%Command{}`.
- The handler's `dispatch … to:` entry in the commanded router is contributed by
  the [command](./command.md) generator, not here.

## Left to you

The body of `handle/2`, left as `# implement logic here` / `# return events`:

- **Shallow** — build the published event from the command's fields; the field
  lists are in the model, and this is the common case.
- **Deep** — guard, compute or derive before emitting; decided by the feature
  spec (`docs/specs/`), never copied from another citizen's handler.

## Tests

In the [operation test](./operation-test.md), under `describe "Command Handler"`:
the generator asserts the returned event type. The field-by-field mapping case
and every branch a deep handler has are manual
([Known gaps](../../README.md#known-gaps)).
