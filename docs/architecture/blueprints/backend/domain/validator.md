---
generator: none
owner: "dependency of mix sp.gen.command (and of the read model for unique fields)"
blueprints:
  - SpGen.Blueprint.Validator
module: "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.Validators.<Validator>"
writes: [module]
---

# Validator

One modelled rule, one Vex validator. A validator answers "is this value
acceptable" — it never fixes data.

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) states the rule as a
  `namedRule`: an aggregate `invariant` or a command `constraint`, with a `name`
  and prose.

## Not a command

There is no `mix sp.gen.validator`. The command that validates with a validator
owns it — the way it owns its router registration — and generating a validator
generates the [internal API](./internal-api.md) accessor it calls and, for a
unique field, the lookup query and read model behind that accessor.

## Patterns

`SpGen.Invariant` asks its patterns in order; the first that claims a rule
decides the shape:

| Pattern | Claims | Generates |
| --- | --- | --- |
| `SpGen.Invariant.UniqueField` | `unique-<field>`, `<field>` a citizen field | validator calling `<do>_by_<field>`, tolerating the record that owns the value; accessor, lookup query, read model |
| `SpGen.Invariant.DomainObjectExists` | `<domain-object>-exists` for the citizen itself, `id` a field | validator calling `<do>_by_id/1` |
| `SpGen.Invariant.FieldRule` | any other rule naming a citizen field (cross-field, cross-aggregate) | a scaffold validator that raises `TODO: implement <rule> validator (see the domain model rule)` |

A rule naming no field (an operational precondition such as
`no-archive-when-in-use`) is not a validator. It resolves to nothing and the run
names it under `Unresolved rules`, with the element it came from — the command
gains no `validates` line, so it is yours to implement, validator **and**
`validates … by:` line, or to leave unenforced on purpose.

A rule that names a field of the citizen but not of the driven element is **not**
reported: `at-most-one-owner` names `coachId`, which `create-widget` carries and
realizes, so running `mix sp.gen.command archive-widget` stays quiet about it.
Only a rule no element of the citizen can realize — one naming no field anywhere
— reaches the report, because that is a fact about the model rather than about
the run you just made.

## Contracts

The error a validator returns is the pattern's, and the caller's assertion names
it:

- unique field: `{:error, :<field>_exists}`
- exists: `{:error, :not_found}`
- a scaffolded rule: whatever the model's rule text demands, stated in the
  example and asserted in the command test.

Never invent a second convention for the same rule, and never a
`def validate(nil, _), do: :ok`: optionality is `allow_nil: true` on the
command's `validates` line ([command](./command.md)).

One `validates` call per field: `Vex.Struct.validates/2` keys validations by
field, so a second call for the same field *replaces* the first. Several
validators on one field are several `by:` pairs inside the same call, which is
why the generator reports an incomplete line as `Outdated` instead of appending.

Validators are not "global": they belong to the constituent, in the module the
rule names.

## Tests

There is no validator test file. Validators are tested as part of the
[command](./command.md) in the [operation test](./operation-test.md): the value
that violates the rule, the value that satisfies it, and for an edit the record
that already owns the value.
