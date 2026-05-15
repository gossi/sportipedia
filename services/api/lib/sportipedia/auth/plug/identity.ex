defmodule Sportipedia.Auth.Plug.Identity do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if user = conn.private[:guardian_user_resource] do
      assign(conn, :user, user)
    else
      conn
    end
  end
end
