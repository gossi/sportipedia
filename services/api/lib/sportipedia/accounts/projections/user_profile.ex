defmodule Sportipedia.Accounts.Projections.UserProfile do
  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :name, :string
    field :picture, :string
  end

  def changeset(profile, attrs \\ %{}) do
    profile
    |> cast(attrs, [:name, :given_name, :family_name, :picture])
  end
end
