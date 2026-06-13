---
$schema: ./recipe.schema.yaml
name: spec
description: Build everything described in a spec document — parse spec, loop over operations, build each with full domain-feature, commit after each
parameters:
  spec_path:
    type: string
    required: true
    description: "Path to the spec markdown file (e.g., docs/specs/catalog/equipment/spec-manage-apparatuses-19-05-2026.md)"
steps:
  - id: parse
    agent: product-specialist
    skill: parse-spec
    with: { spec_path: ${parameters.spec_path} }

  - id: build-loop
    loop:
      over: ${steps.parse.result.operations}
      steps:
        - recipe: domain-feature
          with: { operation: ${item} }
approval: auto
---

# Build Spec Recipe

Build a complete spec: parse the document, extract all operations, and build
each one using the `domain-feature` recipe.

## Structure

1. **Parse** — The Product Owner subagent loads the `parse-spec` skill, reads
   the spec, and returns an ordered list of operation names (commands first in
   spec order, then queries in spec order).

2. **Loop** — For each operation, the builder runs the `domain-feature`
   sub-recipe (find → build-operation → build-endpoint → review-loop).

## Builder Execution Rules

### Spec Context Injection

When delegating any step of `domain-feature` to a subagent, the builder MUST
include the following additional context in the prompt:

- The full spec file content (read it after the `parse` step)
- The PO task_id from the `parse` step, with instruction: "If you encounter
  ambiguous business logic (e.g., 'implement logic here' in command handlers),
  output `QUESTION: <your question>` and stop. The builder will route your
  question to the Product Owner for clarification."

### PO Question Round-Trip

If a subagent (typically the backend-engineer inside `domain-feature`) returns
output containing `QUESTION:`:

1. Extract the question text
2. Resume the PO subagent using its `task_id`:
   - Prompt: "The backend-engineer is implementing `{operation}` and asks: {question}. Answer based on the spec document."
3. The PO returns its answer
4. Resume the backend-engineer (spawn a fresh session or resume the task_id
   if the mechanism supports it) with:
   - The original operation context
   - The PO's answer injected
   - "The Product Owner says: {answer}. Continue with the implementation."
5. Maximum one round-trip per iteration. If the backend-engineer outputs another
   QUESTION after receiving the answer, abort that iteration (see below).

### Git Commit After Each Iteration

After each `domain-feature` sub-recipe completes (regardless of success or
failure), run git commands directly:

```
git add -A
git commit -m "Implement <operation>"
```

The builder runs this directly — it is orchestration, not implementation code.
Do not delegate to a subagent for this.

### Error Handling

- If an iteration succeeds: commit normally, proceed to next operation.
- If an iteration fails (domain-feature errors out, review fails after 3
  attempts, or a second QUESTION round-trip is needed): git-add and commit the
  partial state as-is, then continue to the next operation.

After the loop completes, report a summary to the user:

```
Build complete for {spec_path}:
  ✓ Succeeded: catalog-apparatus, edit-apparatus, archive-apparatus
  ✗ Failed: list-apparatuses, read-apparatus
```

### Precondition

The ESDM domain model files referenced in the spec's `## Domain Model` section
must already exist and be populated. The domain modelling phase is assumed
complete before this recipe runs.
