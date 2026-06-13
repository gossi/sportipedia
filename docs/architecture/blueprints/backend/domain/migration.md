# Migration

Migrations drive a change to the database model.

## Migration Usage

- migrations are append only, deleting an existing one results in an integrity
  error (do NOT do that)
- Use `prefix` appropriately (see example below)
- Use with: `prefix: "<_subdomain>"`
- table name = read model name (as in the domain model)
- table name is singular

### When to use a Migration

- altering fields needs a migration
- read model needs creation
- delete a no longer needed table (this needs to be requested explicitly)

### When NOT to use a Migration

- migration already exists
- Read model is covered by all existing migrations

## Create a Migration

use [`mix ecto.gen.migration`](https://ecto-sql.hexdocs.pm/Mix.Tasks.Ecto.Gen.Migration.html) for that:

```sh
mix ecto.gen.migration <name of the migration>
```

## Example: `CREATE TABLE apparatus`

Correct usage of prefix.

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
