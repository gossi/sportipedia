defmodule Sportipedia.Accounts.Projections.User do
  @moduledoc """
  This represents the account of a user used for login purpose or as a way to
  identify for tagging/user-url.

  Authentication:

  1. With email/password
  2. Through provider
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Sportipedia.Accounts.Projections.UserIdentity
  alias Sportipedia.Accounts.Projections.UserProfile

  @primary_key {:id, :binary_id, autogenerate: false}
  @timestamps_opts [type: :utc_datetime_usec]
  @schema_prefix "accounts"
  schema "users" do
    # Used for communication and to login
    field :email, :string

    # Used for URL path segment to user profile and tagging
    field :username, :string

    field :role, Ecto.Enum, values: [:admin, :user]
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime_usec

    has_many :identities, UserIdentity

    embeds_one :profile, UserProfile

    timestamps()
  end

  def changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:email, :username, :hashed_password])
    |> cast_embed(:profile)
  end
end
