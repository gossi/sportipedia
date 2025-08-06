defmodule Sportipedia.Accounts.Commands.RegisterWithProvider do
  defstruct id: nil,
            email: nil,
            username: nil,
            role: :user,
            provider: nil,
            provider_user_id: nil,
            profile_name: nil,
            profile_picture: nil,
            access_token: nil,
            refresh_token: nil,
            expires_at: nil

  use ExConstructor
  use Vex.Struct

  alias Sportipedia.Accounts.Commands.RegisterWithProvider

  validates(:provider, presence: true)
  validates(:provider_user_id, presence: true)
  validates(:email, presence: true)

  @doc """
  Assign a unique identity for the user
  """
  def assign_user_id(%RegisterWithProvider{} = register, id) do
    %RegisterWithProvider{register | id: id}
  end

  @doc """
  Convert email address to lowercase characters
  """
  def downcase_email(%RegisterWithProvider{email: email} = register_user) do
    %RegisterWithProvider{register_user | email: String.downcase(email)}
  end
end

# defimpl Sportipedia.Support.Middleware.Uniqueness.UniqueFields,
#   for: Sportipedia.Accounts.Commands.RegisterUser do
#   def unique(%Sportipedia.Accounts.Commands.RegisterUser{user_id: user_id}),
#     do: [
#       {:email, "has already been taken", user_id},
#       {:username, "has already been taken", user_id}
#     ]
# end
