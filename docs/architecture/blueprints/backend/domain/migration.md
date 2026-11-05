---
generator: none
owner: "mix ecto.gen.migration"
writes: [migration]
---

# Migration

The database side of a read model. Deliberately **not** an executable blueprint:
a migration file name carries a timestamp and migrations are history, so nothing
here can be reproduced idempotently. The [read model](./read-model.md) documents
the schema; this document states how the table behind it is created.

## Prerequisite

- The read model exists in the [Domain Model](../../../../domain-model/README.md)
  with its fields and unique fields.

## Rules

- Migrations are append only. Deleting an existing one breaks the schema
  migration state — do not do it.
- Always pass the prefix: `prefix: "<_subdomain>"`, on the table and on every
  index.
- Table name = read model name as in the domain model, **singular**.
- `primary_key: false` on the table with `add :id, :binary_id, primary_key: true`,
  matching the read model's `@primary_key`.
- Timestamps in microsecond precision, matching `@timestamps_opts`.
- A unique-field invariant needs the matching `unique_index` — a
  `unique_constraint` in the changeset without the index in the database is a
  race, not a rule.

### When to write one

- The read model is new.
- A field is added, retyped or removed.
- A table is dropped — only when that is explicitly requested.

### When not to

- An existing migration already covers the read model. Check before writing.

## Create a migration

```sh
mix ecto.gen.migration <name of the migration>
```

Run it from `services/api`. The file it creates is yours to fill; the generator
never touches `priv/repo/migrations/`. Verify it against the read model, not
against another migration: fields, types, nullability, prefix and the unique
indexes must match, or the projections fail at runtime with a changeset error
the model cannot explain.

## Example: `CREATE TABLE apparatus`

```elixir
defmodule Sportipedia.Repo.Migrations.CreateApparatusProjection do
  use Ecto.Migration

  def change do
    create table(:apparatus, primary_key: false, prefix: "catalog") do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :description, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:apparatus, [:slug], prefix: "catalog")
  end
end
```
