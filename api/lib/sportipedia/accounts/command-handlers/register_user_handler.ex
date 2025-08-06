defmodule Sportipedia.Accounts.CommandHandlers.RegisterUserHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Accounts.Commands.RegisterUser
  alias Sportipedia.Repo
  alias Sportipedia.Accounts.Projections.User

  def handle(aggregate, %RegisterUser{} = cmd) do
    # Optional validations
    IO.inspect(aggregate, label: "register_user_handler")

    # Persist user directly
    %User{
      id: cmd.id,
      email: cmd.email,
      username: cmd.username,
      role: cmd.role,
      hashed_password: cmd.hashed_password
    }
    |> Repo.insert()

    # # Return :ok or {:ok, aggregate}
    # {:ok, aggregate}
  end
end
