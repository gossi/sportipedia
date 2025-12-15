defmodule Sportipedia.Accounts.Router do
  use Commanded.Commands.Router

  alias Sportipedia.Accounts.Aggregates.User

  alias Sportipedia.Accounts.Commands.{
    RegisterUser,
    RegisterWithProvider
    # UpdateUser
  }

  alias Sportipedia.Accounts.CommandHandlers.{
    RegisterWithProviderHandler,
    RegisterUserHandler
  }

  alias Sportipedia.Support.Middleware.{
    # Uniqueness,
    Validate
  }

  middleware(Validate)
  # middleware(Uniqueness)

  ## , prefix: "user-"
  identify(User, by: :id)

  dispatch(RegisterUser, to: RegisterUserHandler, aggregate: User)
  dispatch(RegisterWithProvider, to: RegisterWithProviderHandler, aggregate: User)

  # dispatch(
  #   [
  #     RegisterUser
  #     # UpdateUser
  #   ],
  #   to: User
  # )
end
