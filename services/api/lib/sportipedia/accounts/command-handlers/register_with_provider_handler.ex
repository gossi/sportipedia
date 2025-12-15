defmodule Sportipedia.Accounts.CommandHandlers.RegisterWithProviderHandler do
  @behaviour Commanded.Commands.Handler

  alias Sportipedia.Accounts
  alias Sportipedia.Accounts.Queries.UserByUsername
  alias Sportipedia.Accounts.Events.UserRegistered
  alias Sportipedia.Accounts.Commands.RegisterWithProvider
  alias Sportipedia.Accounts.Projections.User
  alias Sportipedia.Accounts.Projections.UserIdentity
  alias Sportipedia.Repo

  def handle(_aggregate, %RegisterWithProvider{} = cmd) do
    with {:user_exists, nil} <-
           {:user_exists, Accounts.user_by_provider(cmd.provider, cmd.provider_user_id)},
         {:username_taken, nil} <- {:username_taken, username_taken?(cmd.username)},
         {:ok, user} <- create_user_with_identity(cmd) do
      %UserRegistered{id: user.id}
    else
      {:username_taken, true} ->
        {:error, :username_taken}

      {:user_exists, user} ->
        {:error, {:user_exists, user}}
    end
  end

  defp username_taken?(username) do
    UserByUsername.new(username)
    |> Repo.one()
  end

  defp create_user_with_identity(%RegisterWithProvider{} = cmd) do
    Repo.insert(%User{
      id: cmd.id,
      email: cmd.email,
      username: cmd.username,
      role: cmd.role,
      profile: %{
        name: cmd.profile_name,
        picture: cmd.profile_picture
      },
      identities: [
        %UserIdentity{
          provider: cmd.provider,
          provider_user_id: cmd.provider_user_id,
          profile_name: cmd.profile_name,
          profile_picture: cmd.profile_picture,
          access_token: cmd.access_token,
          refresh_token: cmd.refresh_token,
          expires_at: cmd.expires_at
        }
      ]
    })
  end
end
