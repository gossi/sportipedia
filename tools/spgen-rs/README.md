# spgen-rs — Sportipedia Generators, Rust

spgen transfers the blueprints in `docs/architecture/blueprints/` into
executable form: it reads the ESDM domain model (`docs/domain-model`) and
writes the code the model implies into the existing tree — append-only,
idempotent, in any order. It is a code *continuation* tool, not a
scaffolder.

The BE generators live in [`../spgen`](../spgen) (Elixir); they keep
generating Elixir and are untouched by this workspace. **This workspace is
the FE counterpart**: it generates the TypeScript citizen in
`apps/catalog` from the same domain model — domain objects, schemas,
actions, queries, abilities, ability tests, test-support fixtures and
mock endpoints, and storybook helpers.

## Why Rust, when the BE tool is Elixir

The BE tool's craft is Elixir AST editing (Sourceror + the stdlib
formatter). The FE target is TypeScript: its parser (`oxc_parser`),
structural analysis and printing live in the Rust ecosystem. Language
choice doesn't deduplicate the *semantics* of the model — faithful
porting and a shared fixture corpus do:

* `spgen-model` is a faithful port of the BE tool's language-neutral core
  (ESDM reader, context resolution, naming and path rules, invariant
  patterns, model checks). Tests are ported with it, and both tools read
  the same fixture trees (`tools/spgen/fixtures/domain-model`).
* The blueprint docs under `docs/architecture/blueprints/` are the shared
  intent; the code in either language is only shape.

All BE generator rules carry over to the FE: units as the work item,
presence checks, deferral with back-fill, registration hosts, the same
report groups and exit codes, `--check`, fixtures-driven tests.

## The write-path verdict

The BE merge model reprints the whole tree after inserting units. Whether
that is safe for TypeScript is not a taste question — a round-trip probe
measured it before any blueprint existed (parse → print → parse over all
58 catalog `.ts` files, checking for lost comments and changed code):

> **Verdict 2026-11-14: splice (option B).** 57 of 58 catalog files
> reprint without losing a comment or changing a byte of code;
> `src/support/data/services/store.ts` loses its two trailing comments —
> the known `oxc_codegen` gap ([oxc#19671]). spgen-fe inserts text at
> offsets and never reprints human files.
>
> The probe crate was deleted once it had rendered its verdict; rerun the
> measurement (from git history or against `oxc_codegen` directly) before
> ever reconsidering reprinting.

## Command surface

Groups compose blueprints; artifacts stay individually addressable —
group commands run their members in order and print one merged report.

```
spgen domain-objects <element>   # domain-object, schema, actions, queries, abilities
spgen test-support <element>     # fixtures, endpoints
spgen ability-tests <element>    # ability-test
spgen storybook <element>        # storybook
spgen feature <element>          # all of the above, in build order
spgen <artifact> <element>       # one artifact, for gated/deferred re-runs
```

Elements are addressed by read-model name — `spgen feature position`.
Ambiguity is not guessed: the resolver answers with the full `esdm:`
references (or a `read-model.<name>` prefix) so one name, one citizen —
same resolution rules as the BE tool.

## Building

```sh
cargo build --release          # binaries in target/release
cargo test                     # ported model tests + blueprint tests + golden acceptance
pnpm spgen                     # dev-dependency of the app that uses it (apps/catalog) — auto-builds the Rust binary, SPGEN_NO_AUTOBUILD=1 opts out
```

CI: `.github/workflows/ci_spgen_rs.yml` — fmt, clippy `-D warnings`, tests.

## Milestones

| | | status |
|---|---|---|
| M1 | port `spgen-model` (reader, resolve, naming, pluralize, annotations, relation keyword, fixtures, citizen) with ported tests + shared fixture corpus | **done** |
| M2 | round-trip probe → reprint-vs-splice verdict (probe retired once it ruled) | **done — splice** |
| M3 | unit engine, report, CLI, `pnpm spgen`, `domain-object` artifact end-to-end | **done** |
| M4 | all nine artifacts in group order | **done** |
| M5 | position slice fixed to model wording; `spgen feature position --check` is a clean no-op on the live tree | **done** |
| M6 | second citizen end-to-end + `docs/architecture/blueprints/frontend/` | with the operator |

M5 did three things by hand, all in model direction:

* `readPositiones` → `listPositions` (and `makeListPositionsEndpoint`,
  `mockListPositions`) — the element is *named* `list-positions`;
  `makePresetControl` → `makePositionPresetControl` so a second athlete
  citizen can have its own;
* `actions.ts` resource paths corrected to the plural collection scope the
  BE router serves (`athlete/positions/edit-position`, …) — the old
  singular paths also carried two copy-paste `apparatus` leftovers;
* `x-esdm-relation` added to the `position` read model
  (`apparatusId` → apparatus, `instrumentId` → instrument) and the edit/archive
  endpoint mocks generated in. The catalog app suite is green (36/36).

## Known simplifications (deliberate, revisitable)

* **Formatting deferred** — inserts land Prettier-adjacent, not Prettier-exact;
  the project's lint step normalizes. A `prettier --write` call on touched
  files is the designed upgrade, not a rework.
* **Import placement** appends to the block of its kind; perfectionist's
  exact ordering is left to lint.
* `XFields` is derived, never curated: `Mutable<Pick<X, …>>` over the
  *writable* properties — attributes and relationships, minus `id`, minus
  `readOnly`. Provenance comes from the model (see field vocabulary
  below), not from Pick-list intuition.
* `admin` is a standing role in every ability (`actors: [user]` →
  `user || admin`) — the rule inferred from the hand-written citizens; say
  the word if `admin` should appear only when declared.
* Ability roles come from commands only; query `actors` remain
  server-side enforcement.

## Registration hosts and deferral

`src/<composite>/index.ts` and `tests/<composite>/support/index.ts` follow
the BE rule — *created by the blueprint that writes into it*:

* the **domain barrel** is created by `schema` (its `configureXSchema`
  needs it), while `domain-object` merges in the interface's type export;
* the **test-support barrel** is shared: `fixtures`, `endpoints` and
  `storybook` each own one export block. Whichever artifact's file
  materializes first creates the barrel with its own block; the others
  append theirs. A block never exports a file that does not exist —
  every barrel unit carries the gate of its artifact's file, so a gated
  citizen defers barrel and file *together*, never half a barrel.
* membership presence is order-insensitive: lint may sort an export
  block's names freely without the pickup check seeing a change.

## Field vocabulary

Standard JSON Schema annotations, interpreted in spgen code (like
`spgen.operation` and `x-esdm-relation`, never asserted by validators,
never written into the ESDM core schema):

* **`readOnly: true`** — managed by the owning authority. Stays on the
  interface (it arrives on the wire), is never writable: no `XFields`
  member, no payload key.
* **`writeOnly: true`** — never present when retrieved. Ignored by the FE
  entirely: no interface property, no schema field, no fixture entry, no
  storybook arg.
* **`x-esdm-relation { to, cardinality, inverse? }`** — the identifier of
  a relationship, declared wherever the field appears (read-model schema
  *and* command data). The TS name and type come from `to` — never from
  stripping an `Id` suffix — and the FE always speaks in resolved domain
  objects (`apparatus?: Apparatus`), never in ids.

**Lookup (addressing)** is declared, not guessed: a read query's
`parameters.oneOf` names the properties that address one resource —
ESDM's own definition ("a query is the logical access path to one view")
and the source of the BE router's `:id_or_slug`. From it:

* fixture finders — one per declared param (`findPositionById`,
  `findPositionBySlug`); a storage field that merely *looks* like a slug
  gets none
* the storybook selector and the endpoint read-mock's accessor use the
  **preferred** param: a non-`id` param (canonical `slug`) when declared,
  else `id`
* a read model without a read query: storybook defers with a note,
  finders fall back to `id`

Slug *typing* is exact: a property is `Slug` iff it is named `slug` —
`raw_slug` is a plain string attribute. Actions don't participate: they
address by record and serialize per JSON:API (`data.type` + `data.id`).

The data types are pure views of `XFields` (WarpDrive's
*narrowing-types* pattern): create is `WithPartial<XFields, <optional
keys>>`, update is `Partial<XFields>`, delete has none. **There is no
`& { … }` tail** — a command input that isn't a writable resource field
means the model is broken, and the renderer ignores the field rather
than typing the breakage into the API. Known open model bug:
`catalog-position`/`edit-position` declare `slug` (the *raw* slug) while
the read model marks `slug` `readOnly` — until the command fields are
renamed to `rawSlug`, that input is silently absent from the payload
types.

## Naming rule

Function and const names come from ESDM element names verbatim —
`list-positions` → `listPositions()`. Pluralization happens **only** in
URL segments, using the BE's four-rule `pluralize` ported faithfully
(no inflection crates: their irregular tables would diverge from the BE
router). The `positiones` in the current tree is a hand-written typo,
fixed in M5, not a rule.

