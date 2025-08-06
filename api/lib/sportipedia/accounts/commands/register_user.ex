defmodule Sportipedia.Accounts.Commands.RegisterUser do
  defstruct id: "",
            username: "",
            email: "",
            role: :user,
            password: "",
            hashed_password: ""

  use ExConstructor
  use Vex.Struct

  alias Sportipedia.Accounts.Commands.RegisterUser
  alias Sportipedia.Accounts.Validators.{UniqueEmail, UniqueUsername}
  alias Sportipedia.Auth

  validates(:user_id, id: true)

  validates(:username,
    presence: [message: "can't be empty"],
    format: [
      with: quote(do: ~r/^[a-zA-Z0-9]{1}[a-zA-Z0-9.-]+[a-zA-Z0-9]{1}$/),
      allow_nil: true,
      allow_blank: true,
      message: "is invalid"
    ],
    string: true,
    by: &UniqueUsername.validate/2
  )

  validates(:email,
    presence: [message: "can't be empty"],
    format: [
      with: quote(do: ~r/^[^@,;\s]+@[^@,;\s]+$/),
      allow_nil: true,
      allow_blank: true,
      message: "is invalid"
    ],
    string: true,
    by: &UniqueEmail.validate/2
  )

  validates(:hashed_password, presence: [message: "can't be empty"], string: true)

  @doc """
  Assign a unique identity for the user
  """
  def assign_id(%RegisterUser{} = register_user, id) do
    %RegisterUser{register_user | id: id}
  end

  @doc """
  Convert email address to lowercase characters
  """
  def downcase_email(%RegisterUser{email: email} = register_user) do
    %RegisterUser{register_user | email: String.downcase(email)}
  end

  @doc """
  Hash the password, clear the original password
  """
  def hash_password(%RegisterUser{password: password} = register_user) do
    %RegisterUser{register_user | password: nil, hashed_password: Auth.hash_password(password)}
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
