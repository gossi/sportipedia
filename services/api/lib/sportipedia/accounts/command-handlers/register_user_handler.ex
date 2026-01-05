defmodule Sportipedia.Accounts.CommandHandlers.RegisterUserHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Accounts.Commands.RegisterUser
  alias Sportipedia.Accounts.Events.UserRegistered
  alias Sportipedia.Repo
  alias Sportipedia.Accounts.Projections.User

  def handle(aggregate, %RegisterUser{} = cmd) do
    IO.inspect(aggregate, label: "register_user_handler")

    with {:ok, user} <- create_user(cmd) do
      %UserRegistered{id: user.id}
    else
      {:username_taken, true} ->
        {:error, :username_taken}

      {:user_exists, user} ->
        {:error, {:user_exists, user}}
    end
  end

  defp create_user(%RegisterUser{} = cmd) do
    Repo.insert(%User{
      id: cmd.id,
      email: cmd.email,
      username: cmd.username,
      role: cmd.role,
      profile: %{
        name: cmd.profile_name
      }
    })
  end
end
