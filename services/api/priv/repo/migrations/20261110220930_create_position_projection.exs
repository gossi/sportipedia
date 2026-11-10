defmodule Sportipedia.Catalog.Repo.Migrations.CreatePositionProjection do
  use Ecto.Migration

  def change do
    create table(:position, primary_key: false, prefix: "catalog") do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :lookup_slug, :string, null: false
      add :apparatusId, :binary_id
      add :instrumentId, :binary_id
      add :description, :string

      timestamps(type: :utc_datetime_usec)
    end

    # Backs the `unique-slug-by-equipment` invariant: the projector stores the
    # canonical lookup path (`<equipment-slug>/<position-slug>`, or the bare
    # position slug when unbound) in one spelling, so a plain unique index is
    # enough — no functional index.
    create unique_index(:position, [:lookup_slug], prefix: "catalog")

    # Back the namespace-existence lookups of the same invariant: a position's
    # raw slug resolved inside one equipment namespace.
    create index(:position, [:slug, :apparatusId], prefix: "catalog")
    create index(:position, [:slug, :instrumentId], prefix: "catalog")
  end
end
