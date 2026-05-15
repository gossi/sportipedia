defmodule SportipediaWeb.System.AuthenticationErrorHandler do
  alias SportipediaWeb.System.JSONAPI.ErrorView

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, reason}, _opts) do
    error_map = format(type, reason)
    ErrorView.send(conn, error_map, status_for(type))
  end

  # --- Private ---
  defp format(:invalid_token, :token_expired),
    do: %{title: "Token expired", detail: "The provided bearer token has expired", status: "401"}

  defp format(:invalid_token, :no_token_found),
    do: %{
      title: "Missing token",
      detail: "No bearer token was provided in the Authorization header",
      status: "401"
    }

  defp format(:invalid_token, :token_not_yet_valid),
    do: %{
      title: "Token not yet valid",
      detail: "The bearer token is not yet valid",
      status: "401"
    }

  defp format(:invalid_token, :signature_error),
    do: %{
      title: "Invalid signature",
      detail: "The bearer token signature is invalid",
      status: "401"
    }

  defp format(:invalid_token, reason),
    do: %{
      title: "Invalid token",
      detail: "The provided bearer token is invalid: #{inspect(reason)}",
      status: "401"
    }

  defp format(:unauthenticated, reason),
    do: %{
      title: "Unauthenticated",
      detail: "Authentication is required: #{reason}",
      status: "401"
    }

  defp format(:no_resource_found, _reason),
    do: %{title: "Invalid token", detail: "The requested resource was not found", status: "401"}

  defp format(:already_authenticated, _),
    do: %{
      title: "Already authenticated",
      detail: "Request cannot be made while authenticated",
      status: "400"
    }

  defp format(type, reason),
    do: %{title: humanize(type), detail: humanize(reason), status: "401"}

  defp status_for(:invalid_token), do: 401
  defp status_for(:unauthenticated), do: 401
  defp status_for(:no_resource_found), do: 401
  defp status_for(:already_authenticated), do: 400
  defp status_for(_), do: 500

  defp humanize(atom) when is_atom(atom),
    do: atom |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
end
