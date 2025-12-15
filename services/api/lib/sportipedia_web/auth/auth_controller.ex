defmodule SportipediaWeb.AuthController do
  use SportipediaWeb, :controller

  alias Sportipedia.Repo
  alias Sportipedia.Accounts.Queries.UserByProvider
  alias Sportipedia.Accounts
  alias Sportipedia.Auth

  def login_with_provider(conn, %{"provider" => provider} = params) do
    result =
      with {:ok, provider_auth} <- oauth_callback(params),
           {:ok, user} <- ensure_user_by_provider(provider, provider_auth),
           {:ok, token, _claims} <- Auth.token_for_user(user) do
        {:ok, token}
      else
        {:error, err} ->
          {:error, err}
      end

    login_response(conn, result)
  end

  defp map_provider_auth_to_register_params(provider, provider_auth) do
    %{
      email: provider_auth.user["email"],
      username: provider_auth.user["preferred_username"],
      provider: provider,
      provider_user_id: provider_auth.user["sub"],
      profile_name: provider_auth.user["name"],
      profile_picture: provider_auth.user["picture"],
      access_token: provider_auth.token["access_token"]
    }
  end

  defp ensure_user_by_provider(provider, authorize_response) do
    user =
      UserByProvider.new(provider, authorize_response.user["sub"])
      |> Repo.one()

    case user do
      nil ->
        {:ok,
         Accounts.register_with_provider(
           map_provider_auth_to_register_params(provider, authorize_response)
         )}

      user ->
        {:ok, user}
    end
  end

  defp oauth_callback(%{"provider" => provider} = params) do
    session_params =
      Map.fetch!(params, "session_params")
      |> Map.new(fn {k, v} -> {String.to_atom(k), v} end)
      |> Map.merge(%{state: "nonce"})

    params =
      Map.drop(params, ["provider", "session_params"])
      |> Map.put("state", session_params.state)

    Auth.oauth_callback(String.to_atom(provider), params, session_params)
  end

  defp login_response(conn, {:error, :invalid_credentials}) do
    conn
    |> put_status(500)
    |> json(%{error: %{status: 500, message: "Invalid credentials"}})
  end

  defp login_response(conn, {:ok, token}) do
    json(conn, %{
      token: token
    })
  end
end
