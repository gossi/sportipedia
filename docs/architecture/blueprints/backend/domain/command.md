---
generator: "mix sp.gen.command <operation>"
blueprints:
  - SpGen.Blueprint.Command
  - SpGen.Blueprint.CommandTest
  - SpGen.Blueprint.CommandRouter
  - SpGen.Blueprint.CommandApplication
module: "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Command.<Command>"
writes: [module, operation test, commanded router, commanded application]
---

# Command

The intent to change an aggregate, validated before it is dispatched.

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains the command,
  its data, its `publishes` events and its `constraints`, and the aggregate's
  `invariants`.

## What the generator does

- Struct from the command's `data`: `use TypedStruct`, `use ExConstructor`,
  `enforce: true` per required field, never struct-level.
- `use Vex.Struct` plus one `validates` line per required field and per resolved
  rule, with the validator alias.
- The rules themselves: a `unique-<field>` invariant or an
  `<domain-object>-exists` constraint brings the [validator](./validator.md),
  the internal API accessor it calls, the lookup query behind that accessor and
  the read model that query reads — all in the same run.
- `@moduledoc` describing what the command does to the aggregate, and `@doc` for
  `new/1` — from the model's `description`, or a `TODO:` marker where the model
  is silent.
- Registration: `identify`/`dispatch` in the composite's commanded router, and
  that router in the subdomain's commanded application. Both files are created
  when the composite or subdomain lacks one.

## Tests

In the [operation test](./operation-test.md), under `describe "Command"`:
`requires id`, `id cannot be nil`, and `validates presence of <field>` for every
required field. The invariant cases are still manual — see
[Known gaps](../../README.md#known-gaps) — and assert the error the
[example](./examples/unique-slug.md) states (`{:error, :slug_exists}`), never a
second convention.
