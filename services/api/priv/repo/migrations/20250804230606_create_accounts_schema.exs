defmodule Sportipedia.Repo.Migrations.CreateAccountsSchema do
  use Ecto.Migration

  def change do
    execute("CREATE SCHEMA accounts")
  end
end
