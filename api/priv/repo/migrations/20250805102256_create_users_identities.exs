defmodule Sportipedia.Repo.Migrations.CreateUsersIdentities do
  use Ecto.Migration

  def change do
    create table(:users_identities, primary_key: false, prefix: "accounts") do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :provider_user_id, :string, null: false
      add :profile_name, :string
      add :profile_picture, :string
      add :access_token, :string
      add :refresh_token, :string
      add :expires_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users_identities, [:provider, :provider_user_id], prefix: "accounts")
  end
end
