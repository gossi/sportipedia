# Sportipedia Generator

## Idea

The blueprints under `docs/architecture/blueprints/` describe, in prose, how one
artifact of a citizen looks. spgen transfers them into executable form: it reads
the ESDM domain model and writes the code the model implies into the existing
tree — append-only, idempotent, in any order. It is a code *continuation* tool,
not a scaffolder: it makes no layout decisions, it never rewrites what a human
wrote, and it leaves business logic to the operator.

## Decisions

### 1. The domain model is the input, not the templates

Everything a generator knows about names, fields, rules and operations comes
from `docs/domain-model`. Templates only hold shape. One source of truth:
renaming a field or adding a command is a model edit, and regeneration follows.

### 2. Merging is append-only AST editing

A run parses the target file, checks each unit for presence, inserts the missing
ones as new nodes, and prints the tree back through the project formatter.
Generated code lives next to hand-written code, so a generator that rewrites
loses work and trust. Presence checks make every unit independently idempotent,
which makes partial application normal rather than exceptional.

### 3. The unit is the unit of work

Not the file, not the function: a `use`, an `alias`, one `field`, one `describe`,
one `validates`. Each unit has an identity, a presence check, a renderer, a
placement and optional gates. It is the smallest thing that can be safely
re-applied, reported, deferred or blocked — and it is what makes the following
decisions possible.

Where one line carries several contributions (a `validates` line holds presence
plus one `by:` pair per rule), the presence check reads the *parts*, not just the
field key: a line that exists but has lost a rule is outdated, and outdated is a
report, not an append.

### 4. Gating, deferral and the closure pass

A unit that references another citizen carries a file gate. While the subject is
missing the unit defers: it is reported, nothing is written, the exit code stays
0. When a run *creates* a file, a merge-only closure pass re-applies the gated
units of the constituent's neighbourhood, so referencing code back-fills exactly
when its subject appears. Generation order must not matter, and the tree must
stay compilable at every step — a generator is needed most when the tree is
incomplete.

### 5. Generators are keyed by artifact; invariants cut across them

A generator is one `mix sp.gen.<name>` task running one blueprint per file role
(the command, its test, its router registration). Invariants and command
constraints are a second axis: `unique-slug` is not a file, it is a constraint
in the read model, a query, an internal accessor, a validator, a `validates`
line and tests. Files belong to elements; rules belong to the citizen — so no
single artifact owns a rule.

That second axis is `SpGen.Invariant`: a `namedRule` from the model is resolved
by a pattern (`UniqueField`, `DomainObjectExists`, `FieldRule`) into a validator
descriptor, which `Context` carries as `validators` and the read model, internal
API, validator and command blueprints render. A rule no pattern claims stays in
`Context.unresolved` instead of being silently dropped. The validator is not a
generator: the command that validates with it owns it, through
`Blueprint.dependencies/1`.

### 6. Emit native code, not string templates

Blueprints render Elixir fragments that the parser, compiler and formatter
accept; a wrong shape fails the run, not the build. The output must be
indistinguishable from hand-written code, and the tooling — AST insert,
formatting, presence checks — only works on real code.

### 7. Registration hosts

Files another tool or the operator owns (the web router) stay merge-only and
fail loudly when missing. Files that must exist for a composite to work at all —
its commanded router, the subdomain's commanded application, the supervisor a
projector registers into — are created by the generator that writes into them.
Generating a command into an empty composite must not require hand-created
files, while app-level singletons should not be silently invented.

### 8. A test file appears only with a test

Creating a test module requires that a `describe` actually places; otherwise the
contribution defers. Whoever has a test to write first creates the file. An
empty scaffold is noise, and `--check` must not promise a file the real run would
not write.

### 9. The mix tasks live in the tool, and the app depends on it

`mix sp.gen.*` is defined in `tools/spgen` and reached through a path dependency
(`runtime: false`, dev/test only). Mix compiles a project before dispatching a
task defined *inside* it — and the tree a generator is called to repair is
exactly the one that does not compile. Depending on the tool inverts that safely;
the escript stays usable standalone.

### 10. Reporting and exit codes are part of the interface

Results are grouped — `Created`, `Updated`, `Ignored`, `Outdated`,
`Unresolved rules`, plus `Blocked` / `Failed` — empty groups print nothing, and
deferred files read `Ignored … skipped: spgen <generator>`. The report is how the
operator decides what to run next: a deferral is guidance, a block is an error.
`Outdated` (a line that exists but lacks a rule the model now states) and
`Unresolved rules` (a rule no invariant pattern realizes) are the two ways a
citizen can be behind its model without the run being wrong — both are reported,
neither fails the run, because the merge may not rewrite a line the operator
owns. `--check` uses the same shape in future tense. See `SpGen.Report`.

### 11. Two actors, listed in run order

Generators declare the hexagonal actor they serve (`:domain` inside the hexagon,
`:web` at the HTTP driving adapter), mirroring `backend/domain` vs
`backend/web`. `mix sp.gen` groups by actor and orders each group by dependency:
read model → event → aggregate → query → internal API → command →
command handler → projector → policy → public API, then view → schema →
controller → bruno. The listing doubles as the known-good build sequence.
Blueprints that are only implementation details — the validator, the lookup
query, the registration hosts — are not in the listing: they arrive through
`Blueprint.dependencies/1` of the generator that calls them.

### 12. Tests are acceptance criteria, not unit tests of internals

- **Pickup** — a `--check` sweep over the repo's own citizens must be a no-op.
- **Order independence** — the same citizen generated in forward and reversed
  order must be AST-equal.
- **Black box** — generators are driven through `SpGen.run/2,3`, the same
  interface the CLI uses.

## Non-goals

- **Migrations** — Ecto's generators own naming and history; the read model
  documents the schema, not the migration.
- **Business logic** — handler bodies, query filters and policy rules are
  generated as TODO scaffolds; the blueprints are explicit that the last 1%
  belongs to the spec.
- **Deleting or rewriting** — the tool only adds. Removing generated code is the
  operator's decision.
- **Custom formatting** — output goes through the project's `.formatter.exs`.
