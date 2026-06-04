defmodule Sportipedia.Catalog.Repo.Migrations.CreateApparatusReadModel do
  use Ecto.Migration

  @schema_prefix "catalog"

  def change do
    create table(:apparatus, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :description, :string

      timestamps()
    end

    create unique_index(:apparatus, [:slug])
  end
end
