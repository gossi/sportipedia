defmodule Sportipedia.Repo.Migrations.CreatePositionProjection do
  use Ecto.Migration

  def change do
    create table(:position, primary_key: false, prefix: "catalog") do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :description, :string
      add :apparatus_id, :binary_id
      add :instrument_id, :binary_id

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:position, [:slug], prefix: "catalog")
  end
end
