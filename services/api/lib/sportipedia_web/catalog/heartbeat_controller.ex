defmodule SportipediaWeb.Catalog.HeartbeatController do
  use SportipediaWeb, :controller

  def ping(conn, _) do
    IO.inspect("call ping")
    text(conn, "pong")
  end
end
