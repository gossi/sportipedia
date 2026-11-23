---
name: code-review
description: Review a build against its spec by reading the working tree, the model and the generators' read-only report.
---

# Code Review

## Overview

Judges a build against the spec it came from. The inputs are the spec and the working
tree, nothing else, and the verdict is the review report.

**Executed by the software-architect** in the `review` step of the
[spec recipe](../../recipes/spec.recipe.md). Load
[parse-spec](../parse-spec/SKILL.md) to read the document, and use
[use-sparch](../use-sparch/SKILL.md) for anything the tool answers.

You never edit a file. Where the fix belongs in documentation, name the file and the
sentence. Routing the edit is not yours.

## Steps

### 1. Read the spec

Run parse-spec on `spec_path`. What it states is the standard you review against: the
domain model entries per bucket, the requirements sections, the Quality Assurance
scenarios, and what `Non-requirements` excludes.

### 2. Read the working tree

    git status --short
    git diff

`git status --short` first, because generated files are new and `git diff` alone does
not show a file that has never been staged. Read the files the change set touches for
whatever the diff does not settle.

### 3. Ask the tool for the present state

    mix sp.gen.feature <aggregate> --diff
    pnpm spgen feature <read-model> --dry-run

Both write nothing, and running them yourself gives today's state rather than a number
relayed from an earlier session.

On the frontend the report answers one question, because the suite is re-run for every
read model in scope and its output is what stands: did someone edit a generated file.
Anything it reports as `changed` or `removed` there is a hand edit, and the fix is
regenerating, not keeping the edit and not noting it as acceptable.

### 4. Check the four dimensions

- **Architecture compliance** — trace the implementation against the documented
  pattern: commands → events → aggregate → projection → read model for writes, queries
  → read model for reads. Each step exists, is named as the architecture names it, and
  connects to the next.
- **Coding standards** — module structure, naming conventions, framework usage
  (TypedStruct, TypedEctoSchema, ExConstructor, Vex, Bodyguard), and no CRUD
  terminology in names or comments.
- **Security** — every endpoint has a Bodyguard plug, policies use the guards from
  `Sportipedia.Auth.Roles` that the spec's actors require, commands validate their
  input, and nothing leaks through event payloads or projections.
- **Specification conformance** — each requirement in the document has code behind it,
  each Quality Assurance scenario has a test that runs it, and each `Removed` entry has
  its code gone.

### 5. Check the things a quiet report cannot prove

- **Manual work has no tool verdict.** A migration, a shared validator body, a
  completion slot or a hand-written test is confirmed by reading it, so verify each one
  the spec or a manual page requires, and treat "the report is clean" as silence on the
  subject.
- **Absence after a deletion.** Generators add and never remove, so a report that says
  in sync proves nothing about a field the model dropped. Find the schema field, the
  migration column, the published attribute and the response entry in the code, and
  report whichever survive.
- **Exclusions.** Anything the spec lists under `Non-requirements` must not be present.
  Half-wired siblings are a build breaker here: an action with no command behind it fails
  `--warnings-as-errors`, and a policy clause with the wrong actor is a security hole the
  build inherits silently.
- **Seeding.** No hand-written `sample-*` map where the read model declares
  `schema.examples`. A test seeds a row through the generated fixture.

### 6. Flag what you cannot judge

When documentation is not enough to decide a dimension, say which document is short and
what it would need. Do not assume, and do not fill a gap from the code.

## Report

```yaml
review:
  spec: <spec_path>
  scope: spec
  status: pass | warn | fail

  architecture:
    status: pass | warn | fail
    findings:
      - severity: info | warn | error
        message: "<description>"
        references:
          - "<doc reference>"

  coding_standards:
    status: pass | warn | fail
    findings:
      - severity: info | warn | error
        message: "<description>"

  security:
    status: pass | warn | fail
    findings:
      - severity: info | warn | error
        message: "<description>"

  spec_conformance:
    status: pass | warn | fail
    findings:
      - severity: info | warn | error
        message: "<description>"
        origin: "<spec section, manual page, or model element>"

  summary: "<overall assessment>"
```

`status` is the field the recipe's loop reads. It is `fail` when any finding blocks the
spec being true, `warn` when everything required is present and something is imperfect,
and `pass` otherwise. Every finding names the thing it came from, so the fix can be
found without a paraphrase.

## Verification

- [ ] Did I read the spec before the code, so the document sets the standard?
- [ ] Did I run `git status --short` as well as `git diff`?
- [ ] Did I run the read-only report myself, rather than reuse an earlier answer?
- [ ] Did I judge all four dimensions, or say which one I could not?
- [ ] Did I verify each manual item by reading it, instead of trusting a clean report?
- [ ] Did I verify absence in the code for every `Removed` entry?
- [ ] Did I check that nothing excluded by `Non-requirements` was built?
- [ ] Did I edit any file? (should be: no)
- [ ] Does every finding name its origin?
