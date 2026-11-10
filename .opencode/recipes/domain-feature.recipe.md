---
$schema: ./recipe.schema.yaml
name: domain-feature
description: Build a complete feature slice — every operation of one aggregate, domain and web actors, through design, generation, parallel implementation, review, adjust and commit
parameters:
  spec_path:
    type: string
    required: true
    description: "Path to the spec markdown file governing this aggregate"
  aggregate:
    type: string
    required: false
    description: "The aggregate / constituent name — the slice identity, e.g. 'position'. Derived from the spec's operations when omitted."
  composite:
    type: string
    required: false
    description: "Composite the aggregate lives in, e.g. 'athlete'"
  operations:
    type: array
    required: false
    description: "Operations in the slice. Derived by the design step when omitted."
steps:
  - id: design
    agent: software-architect
    skills:
      - parse-spec
      - plan-domain-feature
    with:
      scope: feature
      spec_path: "${parameters.spec_path}"
      aggregate: "${parameters.aggregate}"
      composite: "${parameters.composite}"

  - id: generate
    agent: backend-engineer
    skill: use-blueprints
    with:
      phase: generate
      aggregate: ${steps.design.result.aggregate}
      design: ${steps.design.result}
      spec_path: "${parameters.spec_path}"

  - id: implement
    loop:
      over: ${steps.design.result.operations}
      mode: parallel
      steps:
        - agent: backend-engineer
          skills:
            - tdd
            - use-blueprints
          with:
            phase: implement
            operation: ${item}
            aggregate: ${steps.design.result.aggregate}
            design: ${steps.design.result}
            generated_files: ${steps.generate.result}
            spec_path: "${parameters.spec_path}"

  - id: review
    agent: software-architect
    with:
      scope: constituent
      aggregate: ${steps.design.result.aggregate}
      operations: ${steps.design.result.operations}
      design: ${steps.design.result}
      files: ${steps.implement.result.files}
      spec_path: "${parameters.spec_path}"

  - id: adjust
    agent: backend-engineer
    skills:
      - tdd
      - use-blueprints
    with:
      phase: adjust
      aggregate: ${steps.design.result.aggregate}
      review: ${steps.review.result}
      design: ${steps.design.result}
      generated_files: ${steps.generate.result}
      files: ${steps.implement.result.files}
approval: auto
---

# Domain Feature Recipe

Build one **feature slice**: every operation of a single aggregate, domain actor
and web actor included. A spec describes one aggregate, so this recipe is the
whole build of a spec.

## Structure

| Step | Agent | Does |
|---|---|---|
| `design` | software-architect | lints the model (`esdm lint`) and checks its completeness (`mix sp.check`), preflights spec against model, translates to technical design, emits the generator call sequence, work packages, deviation register, boundary |
| `generate` | backend-engineer | runs the call sequence verbatim, writes no logic, reports every file touched |
| `implement` | backend-engineer ×N, **parallel** | one operation each: fills residual bodies, writes the tests |
| `review` | software-architect | reviews the constituent as a whole |
| `adjust` | backend-engineer | applies findings, repairs lost registrations, **commits** |

Five calls per spec, plus one background worker per operation.

## Why one slice per aggregate

Operations on one aggregate share `public_api.ex`, `policy.ex`,
`<object>_controller.ex`, `aggregate.ex`, `projector.ex`, `read_model.ex`, the
JSON:API view, the response schemas and the router scope. The design step
therefore loads the shared scaffold once, and generation creates it once, instead
of every operation re-deriving the same files.

## Why the generator runs before any logic is written

Generation is mechanical and idempotent; semantics are not. Splitting them means:

- the shared files exist before the parallel workers start, so nobody generates a
  file another worker is reading,
- workers see exactly which citizens are scaffolded and which bodies are theirs,
- a worker that dies mid-package loses only its own operation, and re-running the
  generators restores the scaffold rather than corrupting it.

Generators are append-only and never rewrite existing nodes, so a re-run is safe
over completed work. **Workers never run generators** — if one finds a citizen
missing, it reports and `generate` or `adjust` runs it. That keeps generation
single-writer.

## Parallel implementation and first-come-first-served

Workers run concurrently, one per operation, and they will occasionally write the
same shared file. That is accepted: these are one-line appends — a policy clause,
a public API function, a controller action, an `apply/2` clause. The lost write is
not silent: `adjust` re-runs `sp.gen … --check`, which detects the missing unit,
and regenerates it.

The one case FCFS does not survive is a **shared validator body** — a file with
one body serving two rules, such as a cross-field invariant used by both create
and update. The design step assigns each shared validator to exactly one owner in
the work packages, so this is routed by the plan rather than raced.

## Convergence, in the adjust step

`adjust` verifies before it regenerates:

1. Inspect the shared files — `web/router.ex`, `<subdomain>/application.ex`,
   `<subdomain>/supervisor.ex`, `<subdomain>/<composite>/router.ex` — plus each
   worker's `FILES:` list. Confirm every operation's route, dispatch entry,
   projector child, policy clause and port function is present.
2. Run `sp.gen … --check` over the slice's elements and classify each divergence
   against the **authorized-deviation register** from the design: intentional, or
   a lost registration.
3. Re-run generators only for lost registrations, and only for purely additive
   elements.

Re-running an element that carries an authorized deviation destroys work — it
resurrects superseded validators, recreates deliberately deleted stubs, and moves
validator pairs back to the field where Vex will drop them. `--check` exits 0 even
when it reports `Outdated`, so classify from its output, never its status code. An
empty or unrecognisable `--check` run is a failure to classify, not a pass.

**One exception never needs classification: fixture names.** The fixture files
are model-owned projections — if a model example was renamed, the repair is
`sp.gen.test_support` (which rewrites them) plus editing the references in test
files whose scaffold embedded the old name. Never re-run a *test-producing*
generator to chase a fixture rename: its merge would append a second scaffold
into worker-filled files. Compilation is the drift detector here — an undefined
fixture function is a warning, and warnings are errors by definition of done.

## Generators add; they never remove

`SpGen.Merge` is append-only, so **a deletion in the domain model does not
propagate to code**. Removing a read-model field leaves the schema field, the
migration column, the published JSON:API attribute and the OpenAPI response entry
in place, and re-running the generator will not clean them up. Model deletions
require an explicit hand-deletion pass, listed as such in the work package.

The consequence for review: `--check` reporting **in-sync** after a model deletion
is not evidence of convergence. Verify absence in the code itself.

## Commit

`adjust` is the only agent that runs git, and it is the last step of the slice, so
no two writers touch the index at once. Its pathspec is the union of the
`generate` report and the workers' `FILES:` lists — both known from the flow,
nothing inferred at commit time. Commit message: `Implement <aggregate>:
<operations>`.

## Handoff to review

Give the architect the design artifact, the worker file lists, the spec path and
the slice boundary. It reads the code itself — do not paraphrase what was built,
because a paraphrase is how a finding becomes an instruction and an instruction
propagates an error. One aggregate means one review sees the assembled constituent:
the whole web surface, the policy set, and the shared files, which is where
cross-operation contamination is visible.

## Definition of done

`mix compile --force --warnings-as-errors` clean in dev and test, `ApiSpec.spec()`
builds, `mix format --check-formatted` clean on the slice, no `TODO:` markers or
raise-stubs in slice-owned files, `--check` reporting only registered deviations,
the slice's tests green with every spec QA scenario executed, no hand-written
`sample-*` seed where the read model declares `schema.examples` (a test seeds a
read-model row through the fixture factory — see
[test-support](../../docs/architecture/blueprints/backend/domain/test-support.md)),
and the commit made.

## Parameters

- `spec_path`: the governing spec.
- `aggregate`: the constituent / aggregate name.
- `composite`: optional, resolved from the spec's frontmatter when omitted.
- `operations`: derived by `design` from the spec and ESDM when omitted; the design
  step is where the list is validated, not assumed.

## Handoff

The final artifact is a complete vertical slice: operation(s) + endpoint + tests
+ docs + Bruno, committed.
