defmodule Sportipedia.Auth.SecretFetcher do
  @moduledoc """
  Custom secret fetcher that retrieves JWKS from better-auth endpoint.
  Implements Guardian.Token.Jwt.SecretFetcher behaviour.
  """

  @behaviour Guardian.Token.Jwt.SecretFetcher

  alias JOSE.JWK

  @ttl :timer.hours(1)

  @impl true
  def fetch_signing_secret(mod, options \\ []) do
    fetch_verifying_secret(mod, nil, options)
  end

  @impl true
  def fetch_verifying_secret(_mod, jwt, _options \\ []) do
    with {:ok, jwks} <- fetch_jwks(),
         {:ok, jwk} <- find_key_by_kid(jwks, jwt) do
      {:ok, jwk}
    else
      error ->
        error
    end
  end

  defp fetch_jwks do
    case Cachex.get(:jwks_cache, :jwks) do
      {:ok, nil} ->
        fetch_and_cache_jwks()

      {:ok, jwks} ->
        {:ok, jwks}

      _ ->
        fetch_and_cache_jwks()
    end
  end

  defp fetch_and_cache_jwks do
    jwks_url = Application.get_env(:sportipedia, :jwks_url)

    case Req.get(jwks_url) do
      {:ok, %{status: 200, body: body}} ->
        Cachex.put(:jwks_cache, :jwks, body, ttl: @ttl)
        {:ok, body}

      error ->
        {:error, {:jwks_fetch_failed, error}}
    end
  end

  defp find_key_by_kid(jwks, jwt) do
    kid = Map.get(jwt, "kid")

    case kid do
      nil ->
        {:error, :no_kid_provided}

      kid ->
        keys = jwks["keys"] || []

        case Enum.find(keys, &(&1["kid"] == kid)) do
          nil ->
            {:error, :kid_not_found}

          key ->
            {:ok, JWK.from(key)}
        end
    end
  end
end
