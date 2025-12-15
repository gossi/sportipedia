defmodule Sportipedia.Repo.Migrations.CreateUsersProjection do
  use Ecto.Migration

  def change do
    execute("CREATE TYPE user_role AS ENUM ('admin', 'user')")

    create table(:users, primary_key: false, prefix: "accounts") do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :username, :string
      add :hashed_password, :string
      add :role, :user_role
      add :confirmed_at, :utc_datetime
      add :profile, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email], prefix: "accounts")
    create unique_index(:users, [:username], prefix: "accounts")
  end
end
