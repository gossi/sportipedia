defmodule Sportipedia.Repo.Migrations.CreateInstrumentProjection do
  use Ecto.Migration

  def change do
    create table(:instrument, primary_key: false, prefix: "catalog") do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :description, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:instrument, [:slug], prefix: "catalog")
  end
end
