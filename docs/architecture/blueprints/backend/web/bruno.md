# Bruno

> **Implemented as an executable blueprint:** `Sportipedia.Codegen.Blueprint.Bruno` — run `mix sp.gen.bruno <operation>`.
> The generator owns the layout (the collection's actual title-case file names), uses
> `folder.yml` per constituent, generates `examples:` from feature scenarios, and is
> create-only: existing docs are never rewritten.

Document endpoints in bruno for direct usage.

File Location:

- Command: `/bruno/<Subdomain>/<Composite>/<Constituent>/<-command>.yml`
- Query: `/bruno/<Subdomain>/<Composite>/<Constituent>/<-query>.yml`

Follow [bruno documentation](https://docs.usebruno.com/llms.txt) for storing
them.

Sorting the endpoints:

1. Commands
2. Queries

Include:

- variables
- examples
