---
test_file: operation test
module: "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Operation.<Operation>Test"
contributors:
  - "mix sp.gen.command <operation>"
  - "mix sp.gen.command_handler <operation>"
  - "mix sp.gen.policy <operation>"
  - "mix sp.gen.public_api <operation>"
  - "mix sp.gen.query <query>"
---

# Operation Test

One test file per operation, built from `describe` blocks contributed by the
generators that write the operation's code. It tests the operation through the
public API — the vertical slice, not the modules.

The shared machinery is `SpGen.Blueprint.TestCaseFile`: the file appears with the
first contributor that has a test to write, and every later run appends only the
missing `describe` and its aliases.

## Prerequisite

- The operation's code has been generated (the same run contributes the tests).

## Generated

- `use Sportipedia.<Subdomain>TestCase`, `@moduletag :integration`, and the
  aliases each `describe` needs — gated on the modules they reference, so a test
  never cites a citizen that does not exist yet.
- `describe "Command"` — requires id, id cannot be nil, presence per required
  field ([command](./command.md)).
- `describe "Command Handler"` — command in, event out
  ([command handler](./command-handler.md)).
- `describe "Policy"` — guest and user cases from the model's `actors`
  ([policy](./policy.md)).
- `describe "Public API"` — success, `{:error, {:validation_failure, _}}` for
  commands, `:not_found` for an unknown read, the collection case
  ([public API](./public-api.md)).
- `describe "Query"` — a placeholder case until the query is implemented
  ([query](./query.md)).

Events, aggregates and projectors are **not** here: the fact owns its own file,
the [event test](./event-test.md).

## Left to you

Test helpers, when a case needs read-model state directly: a private
`new_<domain_object>/1` inserting through
`<DomainObject>ReadModel.insert_changeset/2` and `Sportipedia.<Subdomain>.Repo`,
plus `new_<domain_object>s/1` for collections. Reach the same state through the
public API when the test is about behaviour rather than a table row.

Everything else that is still yours is listed once in
[Known gaps](../../README.md#known-gaps).

## Learnings

- Test names say what the system does through the interface, in the model's
  vocabulary; they do not name modules or private functions.
