---
generator: "mix sp.gen.<name> <element>"
blueprints:
  - SpGen.Blueprint.<Name>
  - SpGen.Blueprint.<Name>Test
module: "Sportipedia.<Subdomain>.<Composite>.<DomainObject>.<Name>"
writes: [module, operation test]
---

# <Name>

One line: what this artifact is for, in the model's vocabulary.

## Prerequisite

- The [Domain Model](../../../../domain-model/README.md) contains …

## What the generator does

- The units it emits, in prose. No code block: the executable blueprint is the
  shape, and a template here would be drift waiting to happen.

## Left to you

Optional — omit it when nothing remains. Where something does: name the anchor the
generated code leaves (`# implement logic here`, a `TODO:` marker, a `raise`) and
the source that decides it (the model, or the feature spec under `docs/specs/`).

## Tests

Link the container the artifact writes into —
[operation test](./operation-test.md), [event test](./event-test.md),
[endpoint test](../web/endpoint-test.md), or a file of its own — and state what
is generated versus what is yours.

## Learnings

Learnings from pull request review. List them by finding. Explain what has
happened (under DO NOT) — and what to DO INSTEAD.

### finding 1

#### DO NOT

#### DO INSTEAD
