defmodule SportipediaWeb.Catalog.HeartbeatController do
  use SportipediaWeb, :controller

  @spec ping(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def ping(conn, _) do
    user = conn.assigns.user

    if user do
      text(conn, "pong from " <> user.givenName)
    else
      text(conn, "pong")
    end
  end
end
