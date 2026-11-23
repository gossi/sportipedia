---
$schema: ./recipe.schema.yaml
name: spec
description: Build everything described in a spec document
parameters:
  spec_path:
    type: string
    required: true
    description: "Path to the spec markdown file (e.g., docs/specs/catalog/athlete/spec-position-05-11-2026.md)"
steps:
  - id: plan
    agent: software-architect
    skills:
      - parse-spec
      - plan-spec
      - use-sparch
    with:
      spec_path: "${parameters.spec_path}"

  - id: implement
    agent: software-engineer
    skills:
      - use-sparch
      - tdd
    with:
      spec_path: "${parameters.spec_path}"
      changes: ${steps.plan.result.changes}

  - id: review-loop
    loop:
      max: 3
      steps:
        - id: review
          agent: software-architect
          skills:
            - parse-spec
            - code-review
          with:
            spec_path: "${parameters.spec_path}"
          exit-when: "${result.status} != 'fail'"

        - id: adjust
          agent: software-engineer
          skills:
            - use-sparch
            - tdd
          with:
            findings: ${steps.review.result}
approval: auto
---

# Build Spec Recipe

Build what a spec document describes. Three steps: plan, implement, and a review loop.

## Terms

- **generated work** — a generator covers it. Where a generator exists, it is used,
  always, through the feature suite for the element it belongs to.
- **manual work** — no generator covers it. A generator's manual page, the output of
  `sparch man <generator>`, is the authority: whatever it lists under "Left to you" is
  manual work, and the agent writes it test-first.
- **the frontend is generated work.** Its suite is re-run for every read model in
  scope, and its generated files are not hand-edited. Output that disagrees with the
  suite is repaired by regenerating, and why it disagreed is a finding about the model
  or the generator.

## Structure

| Step | Agent | Does | Returns |
| --- | --- | --- | --- |
| `plan` | software-architect | reads the spec, then states the work it implies, split into generated and manual | `changes`, `excluded`, `findings` |
| `implement` | software-engineer | runs the generators for the generated items, writes the manual ones test-first | `FILES:` list, and one line per manual item |
| `review` | software-architect | reads the spec and the working tree, asks the tool for today's state | review report with `status` |
| `adjust` | software-engineer | applies the findings | changed files |

## `plan`

Reports what the document states before deciding anything, then states the work that
follows. Each item in `changes` says whether it is generated or manual, names the
element or the "Left to you" entry it comes from, and gives the spec section it came
from so the next agent can find the sentence rather than a summary of it. Generated
items carry the state the read-only report gives today. Manual items carry no claim
about the tree, because the plan does not look at code.

A named element the model does not carry, or a spec link that does not resolve, is a
finding and a stop. Those are defects in the document or in the model, and the
product-specialist owns them.

## `implement`

Works the list, in the order the list gives.

- Generated items go through the suite for the element's aggregate. Nothing a generator
  owns is typed by hand.
- Manual items are written by the agent. It looks first, so a rerun reports the
  migration or the shared validator as already present instead of writing a second one.
- Behavior and tests are written test-first, with every spec scenario covered.
- It finishes with the read-only report clean for each side the spec's `scope` names,
  and the gates below green.

Its return is the file list, used for the report, and one line per manual item: written,
already present, or skipped with the reason.

## `review` and `adjust`

Review receives `spec_path` and nothing else. It reads the document, then the working
tree with `git status --short` and `git diff`, then asks the tool for the present state
itself, so the verdict rests on today's tree rather than an answer passed from an
earlier session.

Adjust receives the findings, nothing else, and re-reads the spec whenever a finding
points at it.

`pass` or `warn` ends the loop, and a `warn` is reported with its findings. `fail` runs
adjust and iterates. Three iterations without a pass is a stop, reported with what stays
open.

## Who answers what

| Question | Answered by |
| --- | --- |
| what should be built | the spec, owned by product-specialist |
| what work follows from it | software-architect, in `plan` |
| what a generated thing is called, and where it lives | sparch |
| in what order to generate | sparch, through the suite |
| does generated code match the model | sparch, read-only |
| does a manual artifact already exist | software-engineer, by looking |
| does the result match the spec | software-architect, in `review` |
| committing | you |

The builder relays `spec_path`, `changes` and findings, forward without rewording, and
relays no path, module name or generator call, because sparch is the source for those.

## Definition of done

Backend: `mix compile --force --warnings-as-errors` clean in dev and test,
`ApiSpec.spec()` builds, `mix format --check-formatted` clean on the change set, no
`TODO:` marker or raise stub left in a file this build owns, and
`mix sp.gen.feature <aggregate> --diff` exits 0.

Frontend: `pnpm spgen feature <read-model>` re-run for every read model the spec
lists, then `pnpm lint` and `pnpm test` green in the app that owns them. Nothing here is
hand-edited around the suite, so a frontend file that does not match what the suite
produces is regenerated and the disagreement is reported.

Whichever side the spec's `scope` declares, and both when it declares both. Then: every
spec scenario has a test that runs it, read model rows are seeded through generated
fixtures rather than hand-written maps, each manual item is accounted for as written,
already present, or skipped with a reason, and nothing the spec excludes was built. No
commit: the recipe never runs git, and the tree is left for you.

## Reporting

```
Build complete for {spec_path}
  plan        {generated} generated · {manual} manual · {findings} findings
  implement   {files} files · manual items: {written} written, {present} present,
              {skipped} skipped
  review      {pass | warn | fail} in {iterations} iteration(s)
  open        {findings still unresolved}
```

On `fail`, report which finding is still open and what it needs. Do not rerun the recipe
from the start.
