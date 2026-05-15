defmodule SportipediaWeb.System.HeartbeatController do
  use SportipediaWeb, :controller

  @spec ping(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def ping(conn, _) do
    user = get_user(conn)

    if user do
      text(conn, "pong from " <> user.givenName)
    else
      text(conn, "pong")
    end
  end

  defp get_user(%Plug.Conn{assigns: %{user: user}} = _conn), do: user
  defp get_user(_), do: nil
end
