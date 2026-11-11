# Contributing to spgen

How to write a test here, and the one rule that makes this suite survivable:

> **A test reads `fixtures/`. Never the live `docs/domain-model`, never code
> generated elsewhere in the repository.**

## Why the rule exists

`docs/domain-model/` is the sportipedia domain's, not this tool's. It moves every
time a stakeholder rephrases an invariant or renames a field, and nothing in the
domain's own definition of "correct" involves spgen's tests. When a test loads it,
a domain edit becomes an spgen failure — a red suite with a green tool, and a
maintainer debugging a rename that was never a bug.

That is not hypothetical: eight tests in this suite broke at once when the live
apparatus model renamed `unique-slug` to `unique-equipment-slug` and added
`valid-slug`. They were asserting "the exact real-world lines" of a citizen the
tool does not own. The assertions were right about the blueprint and wrong about
their input: the same contracts, read from `fixtures/domain-model`, pass for the
same reason they always did, and no future model edit can move them.

The second half of the rule is the same failure in another shape. `mix sp.gen.*`
is append-only and idempotent, so a test that asserts against
`services/api/lib/...` is asserting against whatever the tree happened to be when
a human last ran a generator — state the test neither created nor controls. If the
question is "what does the generator produce?", produce it, in memory, and assert
on that.

## The harness

`test/support/fixture_repo.ex` is the only entry point. It mounts
`fixtures/domain-model/` and `fixtures/repo/` (the hand-owned host files: routers,
supervisor) on an in-memory `SpGen.FS` backend under a virtual repo root, so a
test drives `SpGen.run/2,3` exactly as the CLI does. Nothing touches disk.

| Call | What it gives you |
| --- | --- |
| `FixtureRepo.model()` | the fixture domain model as an `Esdm.t()` — for tests that reason over a model rather than over generated code |
| `FixtureRepo.model_path()` | that model's path, when a test needs file addresses (`resolve/2` by path is a behaviour of its own) |
| `FixtureRepo.element("command.create-widget")` | one element; raises when the fixtures do not model that citizen |
| `FixtureRepo.build()` | an empty repository: fixture model + host files, no generated code |
| `FixtureRepo.run(repo, :generator, ["element"])` | a real run; returns `{:ok, rows}` |
| `FixtureRepo.check(repo, :generator, ["element"])` | the same report, writes nothing — this is how `Outdated` and `Deferred` are asserted |
| `FixtureRepo.read/write/exists?/paths` | the repository's content, repo-relative |
| `FixtureRepo.contents(repo)` + `FixtureRepo.restore(map)` | the tree as an immutable map, and a fresh repository per test from that map |
| `FixtureRepo.shared(key, fun)` | expensive immutable state built at most once per session, on demand (the full chain, the fixture model) |

The acceptance tests are split by subject across `codegen_test.exs`,
`codegen_creation_test.exs`, `codegen_chain_test.exs`, `codegen_query_test.exs`
and `codegen_support_test.exs`, sharing `SpGen.Acceptance` (the chain, `generate/1`,
`generated_repo/0`, the readers and the canonical-AST comparison). See *Cost* below
for why the split matters.

Three shapes cover every test here:

```elixir
# 1. A model read: no repository needed at all
setup_all do
  %{model: FixtureRepo.model()}
end

test "a declared collection read is a collection", %{model: model} do
  {:ok, ctx} = Context.build(model, Esdm.resolve!(model, "query.list-widgets"))
  assert Context.collection?(ctx)
end

# 2. A generated citizen: an empty repo, one run
setup do
  %{repo: FixtureRepo.build()}
end

test "the collection function runs the query citizen", %{repo: repo} do
  {:ok, _} = FixtureRepo.run(repo, :public_api, ["list-widgets"])
  assert FixtureRepo.read(repo, @public_api) =~ "Repo.all(ListWidgets.new(query))"
end

# 3. A report: `check`, and the row shape is the contract
test "a marker an earlier run left is reported, never rewritten", %{repo: repo} do
  assert {:ok, results} = FixtureRepo.check(repo, :query, ["list-widgets"])

  assert Enum.any?(results, fn
           {:checked, @list_query, ids} ->
             Enum.any?(ids, &match?({:stale, {:def, :new, 1}, [_ | _]}, &1))

           _ ->
             false
         end)
end
```

Inline literal data is fine — and is the right shape for a pure function:
`Invariant.resolve(%{"name" => "unique-slug", ...}, fields, "apparatus")` and
`Templates.validates_line(%{name: "slug", ...}, validators)` assert the function's
own arguments. The rule is about *inputs the tool loads*: a model, a repository,
a file. Those come from `fixtures/`.

## Stating a variant without touching the fixtures

A test that needs "what if the model said X" says so on its own copy of the
element, not by editing a shared file:

```elixir
element = Esdm.resolve!(model, "query.list-widgets")

bare = %{
  element
  | doc: put_in(element.doc, ["parameters", "properties", "sort", "sortableFields"], nil)
}

{:ok, ctx} = Context.build(model, bare)
```

Same for an actor list, a missing annotation, a stripped `examples:` block. The
fixture stays the shared baseline; the deviation is visible in the test that
depends on it. When the deviation *is* the shape you keep asserting on, add it to
the fixture model instead — a fixture the whole suite can share beats four
hand-built element structs.

## The fixture model

`fixtures/domain-model/` is one constituent, `widget`, complete enough to drive
every blueprint: a domain/bounded-context/subdomain head, three actors, an
aggregate whose invariants realize as `:unique`, as a two-field `:rule`, and as
unresolved; five commands covering `create`, `update`, `delete` and `none`; six
events (one command publishes two); a read model with per-event `spgen.operation.*`
decisions and `schema.examples`; a `read` and a `collection` query; one feature
with scenarios.

Missing a shape? **Extend the fixtures.** Do not point the test at the live model
"just for this one assertion", and do not import a real citizen's file to compare
against: the comparison you cannot regenerate is the one that breaks.

Keep the fixture world coherent: adding a field to `read-model.widget` changes the
recorded snapshot, so run the chain and re-record deliberately (below), never as a
side effect.

## Cost: what a test here actually pays

A generator run costs ~55ms, and almost all of it is the neighbourhood closure —
creating a citizen re-applies every generator's plans across the constituent,
which is what makes generation order irrelevant. The full chain is 43 runs and
measures **2.28s**; the 43 `--check` sweeps over a finished tree measure 0.4s. A
chain is therefore the same work whether a test needs it or not, and it is the
same chain whichever test asks first.

Measured, in this order of impact:

| Change | Suite |
| --- | --- |
| baseline (2026-11-11, before any of this) | 95s |
| one chain per module instead of per test | 29s |
| closure sweep memoized per process (contexts + plans are pure functions of model/element/options) | 20.7s |
| parsed sources memoized per run by content (243 plans share ~25 files) | 12.7s |
| **split one 45-test file into five theme files** | **6.4s** |
| a fat test re-running the chain to assert on one generated file | 5.9s |

**ExUnit schedules async MODULES, not async tests.** `async: true` and
`max_cases: 22` do not spread one module's tests over the cores — they run one
after another in a single lane, so a big acceptance file is a serial bottleneck
no matter how it is tagged. Split by subject and the cores appear by themselves:
`user` time stayed ~14s while `real` fell from 12.3s to 6.4s. The split keeps
one shared support module (`SpGen.Acceptance`) so the chain, the tree and the
reading helpers exist once; the shared paths there are **macros**, because a test
writes `match?({:checked, archive_command(), _}, row)` and a pattern takes only
literals.

Rules of thumb:

- **One chain per session, on demand.** `FixtureRepo.shared/2` builds expensive
  immutable state once, in a process started by `test_helper.exs`, and hands it
  to whoever asks. `setup_all` that generates is worse than a lazy shared build:
  it is paid even by a run selecting a single unrelated test. With the lazy
  version, `mix test <file>:<line>` costs 0.4s; behind `setup_all` it cost 2.6s.
- **Read a generated tree, don't rebuild it.** `FixtureRepo.contents/1` →
  `FixtureRepo.restore/1`: a test that only inspects output takes a private copy
  of the map, so its writes stay local to it.
- **Assert on the generator that owns the file.** A test about how a read seeds
  when the model states no example needs `spgen controller` for that operation —
  not the whole chain. Re-running the chain to prove one file re-pays the
  acceptance test the snapshot already covers, at forty times the cost.
- **Keep the chains that are the subject.** Creation into an empty repository,
  order independence (the reversed chain), fixed point (`--check` after a full
  chain is a no-op), deferral and back-fill: those runs are the claim.

### What is NOT on the table

Narrowing the closure's FIRST round — re-applying only the plan groups watching
paths this run touched — measures a further ~34% (5.9s → 4.9s). It was tried and
reverted, because one test fails: a creating run must resurrect a unit a human
deleted from a neighbour's file
(`SpGen.TestSupportAcceptanceTest`, "a creating test-support run leaves human
deletions in neighbors alone — :all runs still backfill"). Only a full pass can
discover that deletion. The later rounds ARE narrowed (to plan groups whose
watched paths changed) — that is safe, and it is why a round costs what it looks
at rather than what the whole neighbourhood contains.

If the suite ever needs to be shorter than honest, say so out loud and gate it —
`@tag :chains` on the full-chain acceptances with an excluded-by-default run and
a `mix test --include chains` escape hatch, the way the API suite tags its
DB-backed tests `:integration`. Do not quietly trade a guarantee for seconds.


## The recorded snapshot

`fixtures/snapshots/widget.txt` is the whole generated tree as one reviewable text
— the tool's own golden output.

- Re-record deliberately: `SPGEN_UPDATE_SNAPSHOT=1 mix test test/sp_gen/codegen_test.exs`.
- **Read the diff before you keep it.** A snapshot diff is the generated shape
  reviewed by a human; a diff you cannot explain is a behaviour change.
- A snapshot that moved because a *unit's* presence check moved (a stricter
  `check`, a new `stale`) is a semantics change, not cosmetics — say so in the
  diff's commit message.

## Presence, staleness and what a test must pin

The merge is append-only, so the interesting assertions are about *identity*, not
output text:

- **Idempotence** — a second run reports `Ignored`; `writes(results) == []`.
- **Never a second clause** — a stricter `check` must be paired with a `stale`
  report, or the merge appends a line that shadows the human's. Pin both halves:
  the report names the edit, and the file is byte-identical after the run.
- **No warnings manufactured** — a unit that would add an unused alias or import
  to a body that does not use it must treat that file as satisfied. Assert the
  absent alias too, not only the present one.
- **Deferral** — a gated unit waits and is reported, and the run that creates its
  subject back-fills it through the closure.

## Checks before you push

```sh
cd tools/spgen
mix compile --warnings-as-errors   # the tool is warning-free
mix format --check-formatted
mix test                           # the whole suite, ~30s
```

`tools/spgen` is a path dependency of `services/api`, so the API's own
`mix compile --warnings-as-errors` and `mix test` rebuild it — those two suites
are the contract with the live project, and neither may read the live tree to
prove itself.
