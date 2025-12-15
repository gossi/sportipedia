defmodule Sportipedia.Accounts.Aggregates.User do
  defstruct [
    :id,
    :username,
    :email,
    :hashed_password,
    :profile
  ]

  alias Sportipedia.Accounts.Aggregates.User

  # alias Sportipedia.Accounts.Commands.{
  #   RegisterUser
  #   # UpdateUser
  # }

  alias Sportipedia.Accounts.Events.{
    # UserEmailChanged,
    # UsernameChanged,
    # UserPasswordChanged,
    UserRegistered
  }

  @doc """
  Register a new user
  """

  # def execute(%User{id: nil}, %RegisterUser{} = register) do
  #   %UserRegistered{
  #     user_id: register.user_id,
  #     username: register.username,
  #     email: register.email,
  #     hashed_password: register.hashed_password
  #   }
  # end

  # @doc """
  # Update a user's username, email, and password
  # """
  # def execute(%User{} = user, %UpdateUser{} = update) do
  #   Enum.reduce([&username_changed/2, &email_changed/2, &password_changed/2], [], fn change,
  #                                                                                    events ->
  #     case change.(user, update) do
  #       nil -> events
  #       event -> [event | events]
  #     end
  #   end)
  # end

  # state mutators

  def apply(%User{} = user, %UserRegistered{} = registered) do
    %User{
      user
      | id: registered.id
    }
  end

  # def apply(%User{} = user, %UsernameChanged{username: username}) do
  #   %User{user | username: username}
  # end

  # def apply(%User{} = user, %UserEmailChanged{email: email}) do
  #   %User{user | email: email}
  # end

  # private helpers

  # defp username_changed(%User{}, %UpdateUser{username: ""}), do: nil
  # defp username_changed(%User{username: username}, %UpdateUser{username: username}), do: nil

  # defp username_changed(%User{id: user_id}, %UpdateUser{username: username}) do
  #   %UsernameChanged{
  #     user_id: user_id,
  #     username: username
  #   }
  # end

  # defp email_changed(%User{}, %UpdateUser{email: ""}), do: nil
  # defp email_changed(%User{email: email}, %UpdateUser{email: email}), do: nil

  # defp email_changed(%User{id: user_id}, %UpdateUser{email: email}) do
  #   %UserEmailChanged{
  #     user_id: user_id,
  #     email: email
  #   }
  # end

  # defp password_changed(%User{}, %UpdateUser{hashed_password: ""}), do: nil

  # defp password_changed(%User{hashed_password: hashed_password}, %UpdateUser{
  #        hashed_password: hashed_password
  #      }),
  #      do: nil

  # defp password_changed(%User{id: user_id}, %UpdateUser{hashed_password: hashed_password}) do
  #   %UserPasswordChanged{
  #     user_id: user_id,
  #     hashed_password: hashed_password
  #   }
  # end
end
