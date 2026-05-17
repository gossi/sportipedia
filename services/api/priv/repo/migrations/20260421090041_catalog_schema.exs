defmodule Sportipedia.Repo.Migrations.CatalogSchema do
  use Ecto.Migration

  def change do
    execute("CREATE SCHEMA catalog")
  end
end
