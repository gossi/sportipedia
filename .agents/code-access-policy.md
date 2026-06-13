# Code Access Policy

Documentation is the single source of truth. Existing code may be outdated.

## Decision Procedure

Before reading code, ask: "What am I trying to learn?"

| Want to learn...                               | Source        |
| ---------------------------------------------- | ------------- |
| Patterns, conventions                          | Documentation |
| Architecture, structure                        | Documentation |
| Domain Model                                   | Documentation |
| Domain Behavior                                | Documentation |
| Framework/library behavior                     | Documentation |
| Implementation details                         | Code          |
| Delta calculations                             | Code          |
| Framework/library inner implementation details | Code          |

## Rules

1. Check documentation first — always
2. If documentation covers your question, use it. Do not read code.
3. If documentation doesn't cover your question, there must be an instruction where to read code from.
4. If code and documentation conflict, documentation wins.

## When to NOT Discover Code

- File naming or directory structure
- Module naming: This must be answered through of documentation.

If anything of this cannot be answered through documentation, stop immediately and report this.
This is a documentation gap!

## When to Read Code

You may ONLY read code for:

1. **Framework/Library internals**: Understanding how a third-party library works (e.g., reading `commanded` source to understand its macros)
2. **Delta calculation**: You are editing a specific file and need to see its current content to compute the exact change
3. **Implementation details**: Only inner workings, eg. function bodies. Never API related code.

You may NEVER read code for:

- Finding patterns
- Find existing patterns
- Checking "how it's done elsewhere"
- Understanding directory structure
- Verifying your implementation matches existing code
- Finding test examples

## If You Violate the Policy

If you realize you have read forbidden code:

1. **Stop immediately** — do not continue using that knowledge
2. **Discard what you read** — base your next action only on documentation
3. **Acknowledge the violation** — tell the user what you read and that you are discarding it
4. **Restart from docs** — re-read the relevant skill/architecture docs and proceed from there

## Hard Failure Protocol

Reading implementation code for patterns, conventions, or reference is a **task failure**, not a warning.

If you read forbidden code:

1. **STOP immediately** — do not write any code based on what you read
2. **Announce**: "VIOLATION: I read implementation code at `<path>`. This is a hard failure."
3. **Discard** all conclusions, patterns, or assumptions drawn from that code
4. **Restart** the task using ONLY documentation (skills, architecture docs, domain model)
5. **Do NOT proceed** until the user confirms

Reading code is not a warning — it is a task failure.
