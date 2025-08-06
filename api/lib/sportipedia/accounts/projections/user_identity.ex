defmodule Sportipedia.Accounts.Projections.UserIdentity do
  use Ecto.Schema

  alias Sportipedia.Accounts.Projections.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :utc_datetime_usec]
  @schema_prefix "accounts"
  schema "users_identities" do
    field :provider, :string
    field :provider_user_id, :string
    field :access_token, :string
    field :refresh_token, :string
    field :expires_at, :utc_datetime
    field :profile_name, :string
    field :profile_picture, :string

    belongs_to :user, User, type: :binary_id

    timestamps()
  end
end
