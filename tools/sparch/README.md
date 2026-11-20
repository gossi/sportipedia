# sparch — Sportipedia Generators

sparch transfers the blueprints in `docs/architecture/blueprints/` into
executable form: it reads the ESDM domain model (`docs/domain-model`) and
writes the code the model implies into the existing tree — append-only,
idempotent, in any order. It is a code *continuation* tool, not a
scaffolder.

The workspace is the **single tool home**: the FE generator ships here
(`sparch-typescript`), and the BE generators port here — from Elixir
([`../spgen`](../spgen), still the live oracle) into `sparch-elixir`. The
Elixir surface the API uses (`mix sp.gen.*`, `mix sp.validate` — the
successor of `sp.check`) does not
change: `elixir/` keeps a little binding whose tasks delegate to the
binary, exactly as the FE surface stays `pnpm spgen` through `typescript/`.

* `crates/sparch-model` — the language-neutral core, ported once and read
  by both tools: ESDM reader, resolution, naming and path rules, the
  invariant patterns, fixture-key grammar, placeholder engine.
* `crates/sparch-typescript` — the FE generator (TypeScript citizen in
  `apps/catalog`): domain objects, schemas, actions, queries, abilities,
  ability tests, test-support fixtures and mock endpoints, storybook.
* `crates/sparch-elixir` — the BE generator (Elixir citizen in
  `services/api`), porting in waves; `read_model` is through the parity
  gate, the rest of the registry answers with a pointer to the Elixir
  tool until its wave lands.
* `crates/sparch` — the crossover tool: the capability tree, the manual
  (the blueprint docs in `man/blueprints`, the generated man pages in
  `man/roff`), architectural answers (placement and naming), model
  validation, and the generate face over the engines.
* `crates/sparch-mcp` — the MCP server (stdio, read-only). Five tools:
  `sparch_capabilities`, `sparch_validate`, `sparch_man`,
  `sparch_arch_location`, `sparch_arch_name`. No writes, no formatting —
  the server answers questions and hands out the binding calls that do
  the work.
* `fixtures/` — the shared corpus: `domain-model` (one superset tree —
  the widget citizen from the Elixir tool's tests plus the
  apparatus/instrument/position/exercise citizens), `repo` (the
  hand-owned BE hosts a generated tree registers into), `snapshots` (the
  oracle's generated widget tree, the parity baseline).

Faithful porting and the shared corpus are what deduplicate the
*semantics* of the model — language choice alone does not:

* The blueprint docs under `docs/architecture/blueprints/` are the shared
  intent; the code in either language is only shape.
* All BE generator rules carry over to the FE and back: units as the work
  item, presence checks, deferral with back-fill, registration hosts, the
  same report groups and exit codes, `--dry-run`, fixtures-driven tests.

## The write-path verdicts

The BE merge model (Elixir tool) reprints the whole tree after inserting
units. Whether that is safe is not a taste question — each language
measured it before blueprints existed.

> **Verdict 2026-11-14 (TypeScript): splice (option B).** 57 of 58
> catalog files reprint without losing a comment or changing a byte of
> code; `src/support/data/services/store.ts` loses its two trailing
> comments — the known `oxc_codegen` gap ([oxc#19671]). sparch-typescript
> inserts text at offsets and never reprints human files.
>
> The probe crate was deleted once it had rendered its verdict; rerun the
> measurement (from git history or against `oxc_codegen` directly) before
> ever reconsidering reprinting.

> **Verdict 2026-11-16 (Elixir): tree-sitter presence, splice, format in
> the binding.** No maintained Rust Elixir printer or formatter exists,
> so reprinting is off the table by construction. The probe
> (`crates/sparch-elixir/tests/probe.rs` and the `elixir` module tests)
> established that tree-sitter-elixir answers every structural question
> `SpGen.Source` asked (directives by rank, DSL entries by rendered first
> argument, keyword pairs with repeated keys for the stale check, defs by
> name/arity, scopes, children lists) and that insertions land at offsets
> with identical identity semantics. `parity.rs` then ran the Elixir
> oracle and the port over the same fixture sandbox: the splice output,
> put through the project's own `Code.format_string!` (the same engine
> the binding reaches by `mix format`), is **byte-identical** to the
> oracle's reprint+format output.
>
> Consequence for the format question: the binary never formats. The mix
> binding runs `mix format` over `services/api` after a successful write
> run — whole project, cheap (CI keeps the tree formatted anyway), and it
> reads the project's `.formatter.exs` natively, so the old
> `Formatter.opts` evaluation and `import_deps` walk disappear with the
> Elixir tool. Non-Elixir artifacts (Bruno YAML under `bruno/`) are
> outside every formatter pattern and unaffected.

## The sparch tool and the MCP face

```
sparch generate                        capability list (language → suites → generators, binding calls)
sparch generate <gen|suite> <element>  runs ported engines in-process; pending ones print the
                                      binding call to type instead
sparch validate [targets]              model completeness (the sp.check rules, parity-pinned)
sparch man [<generator>]               the man page of a generator or artifact; the index when none is named
sparch man --plain | --roff            plain text rather than the pager, or the roff source
sparch man --index                     the blueprint docs and the generator each one serves
sparch man --write [dir]               regenerate man/roff, the pages the binary embeds
sparch arch location <gen> <element>   where the generated code lives
sparch arch name <gen> <element>       what it is named
sparch mcp                             the stdio MCP server (read-only)
```

Argument syntax is clap's on all three binaries: generated `--help`
(with the curated address/option lore in `after_help`), `--version`,
usage errors exit 2. Run-level reporting is unchanged and stays
byte-equal to the Elixir tool: parse-layer wording is UI, artifacts and
reports are the contract. From the repo root the tool is one alias away:
`cargo sparch capabilities` (`.cargo/config.toml`).

The manual has two layers under `man/`. `blueprints/` holds the prose its
owner writes, a copy of `docs/architecture/blueprints/`. `roff/` holds the
generated man pages, one per BE generator and per FE artifact, plus
`sparch.1`, the index. `sparch man --write` builds them from the registry
facts (element kinds, template operations, the `@shortdoc` descriptions)
and that prose, and the binary embeds the committed files at build time, so
`sparch man <generator>` answers from the binary and never reads the
filesystem. The pages carry no date, so the same input gives byte-identical
output. The staleness test regenerates them and compares against the
committed files, which means a new generator or a changed description fails
the build until `sparch man --write` has run. `sparch man` renders through
`groff` or `man` when either is installed, and prints the roff source when
neither is.

`sparch mcp` execs the sibling `sparch-mcp` binary; opencode starts the
same server from `.opencode/opencode.jsonc` (`sparch` entry).

Where the tools answer, the data is the generators' own: the BE
path/module templates (ported ahead of their blueprint waves), the FE
`Layout`, the naming engine, and `SpGen.Check`'s contracts.

## Command surface

One vocabulary across the tools: **blueprints render units; generators run
blueprints; suites run generators.** A generator is one command over one
element; a suite is a named composition over one scope — `operation`,
`endpoint`, `feature` (BE) or a citizen facet (FE) — and it runs its
generators in the known-good build order, refusing until every member is
ported. A suite scoped to a piece of functionality is what the recipes call
a **slice**: the word names the scope, the tier is the suite.

FE — through the app (`pnpm spgen` runs the wrapper around `sparch-typescript`).
Suites compose generators; generators stay individually addressable —
suite commands run their members in order and print one merged report.

```
sparch domain-objects <element>   # suite: domain-object, schema, actions, queries, abilities
sparch test-support <element>     # suite: fixtures, endpoints
sparch ability-tests <element>    # suite: ability-test
sparch storybook <element>        # suite: storybook
sparch feature <element>          # suite: all of the above, in build order
sparch <generator> <element>      # one generator, for gated/deferred re-runs
```

BE — unchanged from the API (`mix sp.gen.*`), now delegating to
`sparch-elixir`:

```
mix sp.gen                                              # listing: generators and suites, with port status
mix sp.gen.<generator> <element> [options]              # one generator
mix sp.gen.operation <command|query> [options]          # suite: domain actor of one operation
mix sp.gen.endpoint  <command|query> [options]          # suite: web actor of one operation
mix sp.gen.feature   <aggregate> [options]              # suite: whole constituent, both actors
mix sp.validate [targets]            # model contract gate (was sp.check)
```

Slices take no `--template` — every member generator reads the operation
from the model. Test support belongs to `feature`, not to a single
`operation` (fixtures are read-model owned projections).

Elements are addressed by read-model name — `sparch feature position` —
or by esdm reference, file, or `kind.name` on the BE side. Ambiguity is
not guessed: the resolver answers with the full `esdm:` references (or a
`read-model.<name>` prefix) so one name, one citizen — same resolution
rules on both sides.

## Building

```sh
cargo build --release          # binaries in target/release
cargo test                     # ported model tests + blueprint tests + golden acceptance
pnpm spgen                     # dev-dependency of the app that uses it (apps/catalog) — auto-builds the Rust binary, SPARCH_NO_AUTOBUILD=1 opts out
mix sp.gen.<name> <element>    # from services/api via the binding in elixir/ — auto-builds sparch-elixir the same way
cargo run -p sparch -- man read_model   # the manual, without any binding
```

The BE parity test needs the oracle and is opt-in:
`SPARCH_ORACLE=../spgen/spgen cargo test -p sparch-elixir --test parity`.

CI: `.github/workflows/ci_sparch.yml` — fmt, clippy `-D warnings`,
tests (all crates, including the MCP smoke), plus the Elixir binding job
(compile + format check). The two gated parities need Elixir and are opt
in: `SPARCH_ORACLE=<escript> cargo test -p sparch-elixir --test parity`
(write path), `SPARCH_VALIDATE_MIX=1 cargo test -p sparch --test validate_parity`
(validate findings). `.github/workflows/ci_spgen.yml` keeps testing the
Elixir tool while it is live.

## Milestones

| | | status |
| --- | --- | --- |
| M1 | port `sparch-model` (reader, resolve, naming, pluralize, annotations, relation keyword, fixtures, citizen) with ported tests + shared fixture corpus | **done** |
| M2 | round-trip probe → reprint-vs-splice verdict (probe retired once it ruled) | **done — splice** |
| M3 | unit engine, report, CLI, `pnpm spgen`, `domain-object` artifact end-to-end | **done** |
| M4 | all nine artifacts in group order | **done** |
| M5 | position slice fixed to model wording; `sparch feature position --dry-run` is a clean no-op on the live tree | **done** |
| M6 | second citizen end-to-end + `docs/architecture/blueprints/frontend/` | with the operator |

BE port waves (the move of `../spgen` into this workspace):

| | | status |
| --- | --- | --- |
| B0 | write-path probe: tree-sitter-elixir presence, splice, format — verdict recorded above | **done** |
| B1 | `sparch-model` completed for the BE: invariant patterns, placeholder template engine, shared fixture corpus merged (widget + hosts + snapshots) | **done** |
| B2 | `sparch-elixir` engine: CLI, options, resolution, unit application, deferral + closure, report, `read_model` end-to-end | **done** |
| B2+ | the suite tier: `operation`, `endpoint`, `feature` with the membership gate, merged reports, binding tasks | **done** |
| B3 | blueprint waves: domain actor (event → aggregate → query → internal API → command → handler → projector → policy → public API), test-support projections, web actor (view → schema → controller → bruno) | **done** |
| B4 | `check` engine port — `sparch validate`, findings byte-equal to `SpGen.Check` (`SPARCH_VALIDATE_MIX=1` gate) | **done** |
| T1 | `sparch` crossover binary + `sparch-mcp` server + embedded manual + arch answers | **done** |
| B5 | cutover: every generator green on the parity gate, `services/api` dep repointed to `elixir/`, `../spgen` deleted, CI folded | pending (B3 and B4 are done and the whole-citizen parity gate is green, the cutover itself has not happened) |

The parity gate for each wave: the oracle and the port generate the same
citizen into fresh copies of `fixtures/repo`; formatted outputs compared
byte for byte (the `parity.rs` method), plus pickup, resurrection and
order independence on the fixture tree.

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

Standard JSON Schema annotations, interpreted in sparch code (like
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
