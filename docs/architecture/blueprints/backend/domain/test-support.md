---
generator: "mix sp.gen.test_support <read-model>"
blueprints:
  - SpGen.Blueprint.Fixtures
  - SpGen.Blueprint.Factory
module: "Sportipedia.TestSupport.<Subdomain>.<Composite>.<DomainObject>Fixtures"
writes: [fixtures module, factory module]
---

# Test Support

The model's fixtures — declared data for tests — and the factories that turn
fixtures into persisted read models. Two outputs, two ownership models: the
fixture file is a **projection** of the model (rewritten whole), the factory
file is the composite's **append-only ledger** (one `new_*` pair per read
model).

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) read model carries a
  `schema` block; fixtures are its `schema.examples`.
- Each example names itself with a **fixture key** as its `id`:
  `<composite>:<read-model>:<mnemonic>`, kebab-case segments
  ([naming](../../naming-substitution.md#fixture-keys)).
- Example fields must be declared by the schema and carry its required
  properties; values in `*Id` fields are fixture keys or real UUIDs.
- `mix sp.check` is the gate: it reports every violation of this contract
  before and independently of generation.

## What the generator does

**Fixtures file** (`test/support/<_subdomain>/<composite>/fixtures/<domain_object>s.ex`):
one zero-arity function per example, in model order — mnemonic snake-cased
(`equipment:apparatus:parallel-bars` → `parallel_bars/0`), returning the read
model's struct, typed with the read model's own `@spec`. Ids and references
materialize as `UUID.uuid5(:dns, "<key>")`: one mnemonic names one thing in
every environment forever, and every value is a real UUID. The aggregate
function (`def apparatuses, do: [...]`) lists them all. The `@moduledoc`
carries provenance: the file is owned by the model.

**Factory file** (`test/support/<_subdomain>/<composite>/<composite>.ex`):
`new_<domain_object>/1` with two clauses — the fixture struct (mapped to
attributes; Ecto's `cast/3` takes a `:map`, not a struct) and a plain
attribute map — and `new_<domain_object>s/1`, which **raises** with the
changeset errors when a seed fails: a half-seeded world is the most confusing
failure mode a test can have. Aliases for the read model and the subdomain
`Repo` land with their first consumer.

A read model without examples still gets its factory: the factory is about the
schema's shape, the fixtures are about its data. A run against a model whose
examples violate the fixture contract fails with every message and writes
nothing.

Two rules keep this generator inside its own bounds. The read model is a
**dependency** of both blueprints: it is the one foreign citizen the run may
create, and it arrives in-run so `ReadModel.t()` and the struct always resolve.
And its **closure scope is `:none`**: creating its own files never triggers the
neighborhood sweep — units a human deleted in events, queries or commands stay
deleted. Generators whose code is referenced by others keep the `:all` sweep.
A test scaffold that seeds through the factory does reference these files, but
its blueprint owns the whole file and creates it in one shot (gates only defer a
merge into a file that already exists, by which time the fixtures are there), so
`:none` stands: flipping to `:all` would resurrect seeds a human removed.

## Left to you

- The examples themselves are domain content: declare them in the read model.
- Hand-written seeds: the struct clause's absence reports as `Outdated` with
  the exact clause to add — the merge never edits an existing function.
- Naming drift is a refactoring: when an example is renamed, fixtures
  regenerate and stale call sites fail compilation — update the callers'
  references; never re-run the test-producing generators to "repair" them.

## Tests

No test file of its own: the fixtures are tested by their consumers, and
`SpGen` covers the generator itself (fixtures, projection semantics, the
`sp.check` engine) in `tools/spgen/test`.
