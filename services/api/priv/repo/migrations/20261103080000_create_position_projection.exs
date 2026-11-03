defmodule Sportipedia.Repo.Migrations.CreatePositionProjection do
  use Ecto.Migration

  def change do
    create table(:position, primary_key: false, prefix: "catalog") do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :description, :string
      add :apparatusId, :binary_id
      add :instrumentId, :binary_id
      add :archivedAt, :utc_datetime_usec

      timestamps(type: :utc_datetime)
    end

    create unique_index(:position, [:slug], prefix: "catalog")
  end
end
