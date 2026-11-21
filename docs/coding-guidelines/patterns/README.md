# Patterns

Pattern pages record learnings applying a model rule and a generator: the
exact error atom, the status code, the optionality rule, the shape a reviewer
must see in the generated file. They are discoveries from review, written so
the next similar slice reaches for the same answer instead of rediscovering it.

Read them before generating code that carries such a rule, and while
reviewing the result. They govern what remains to the human on top of the
generated file; what the generator itself does is not duplicated here —
`sparch man <generator>` is authoritative for that, and `sparch validate`
says what the model is missing.

## Pages

- [unique-slug](unique-slug.md) — the `unique-<field>` rule: lookup, accessor,
  validator and the plain unique index behind them.
- [domain-object-exists](domain-object-exists.md) — the `<domain-object>-exists`
  rule: the UUID guard, `:not_found`, and why a reference into another
  aggregate needs its own atom.
- [status-codes](status-codes.md) — where the status an endpoint test asserts
  must come from, and the matrix it asserts against.
- [test-naming](test-naming.md) — a test name is the contract it asserts, said
  in the model's vocabulary.
- [test-data](test-data.md) — the fixture for a table row, the public API for
  behavior; assert the rule that speaks, never a crash.
- [test-support](test-support.md) — the sandbox, request helpers, fixtures
  and factories already exist; use them instead of building your own.

## Format

One page per recurring problem. A worked rule keeps its whole argument in one
file: what the pattern claims and does not claim, the contract, the pieces it
realizes as a review reference, and the findings. Small findings join the
page of their problem; a page opens with one line saying what it addresses.
