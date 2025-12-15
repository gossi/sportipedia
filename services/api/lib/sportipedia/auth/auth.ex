defmodule Sportipedia.Auth do
  @moduledoc """
  Boundary for authentication.
  Uses the bcrypt password hashing function.
  """

  alias Sportipedia.Auth.Guardian
  alias Sportipedia.Accounts

  #
  #
  # Username + Password
  #

  def authenticate(email, password) do
    user = Accounts.user_by_email(email)

    case user do
      nil ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      user ->
        if validate_password(password, user.hashed_password) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
  end

  #
  #
  # OAuth
  #

  @spec oauth_callback(atom(), map(), map()) :: {:ok, map()} | {:error, term()}
  def oauth_callback(provider, params, session_params) do
    config = config!(provider)

    config
    |> Keyword.put(:session_params, session_params)
    |> config[:strategy].callback(params)
  end

  defp config!(provider) do
    config =
      Application.get_env(:sportipedia, :strategies)[provider] ||
        raise "No provider configuration for #{provider}"

    Keyword.put(config, :redirect_uri, "http://localhost:4000/oauth/#{provider}/callback")
  end

  #
  #
  # Utils
  #

  @doc """
  Hash a password
  """
  def hash_password(password), do: Bcrypt.hash_pwd_salt(password)

  @doc """
  Verify password against a hash
  """
  def validate_password(password, hash), do: Bcrypt.verify_pass(password, hash)

  def token_for_user(user) do
    Guardian.encode_and_sign(user)
  end
end
