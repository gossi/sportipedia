defmodule SportipediaWeb.System.FallbackController do
  use SportipediaWeb, :controller

  alias SportipediaWeb.System.JSONAPI.{
    AuthorizationErrorFormatter,
    ErrorView,
    ValidationErrorFormatter
  }

  # handle bodyguard authorization error
  def call(conn, {:error, :unauthorized}) do
    ErrorView.send(conn, AuthorizationErrorFormatter.format(:unauthorized), 403)
  end

  def call(conn, {:error, {:authorization_failure, reason}}),
    do: ErrorView.send(conn, AuthorizationErrorFormatter.format(reason), 401)

  def call(conn, {:error, {:validation_failure, errors}}),
    do: ErrorView.send(conn, ValidationErrorFormatter.format(errors), 422)

  def call(conn, {:error, :not_found}),
    do: ErrorView.send(conn, %{title: "Not found", status: 404}, 404)

  def call(conn, unknown) do
    IO.inspect(unknown, label: "unknown error")

    ErrorView.send(conn, %{title: "Unknown Error", status: 500}, 500)
  end
end
