defmodule SportipediaWeb.System.JSONAPI.ErrorView do
  alias Plug.Conn

  @media_type "application/vnd.api+json"
  @doc """
  Sends a JSON:API error response.
  Accepts a single error map or a list of error maps.
  Returns the halted conn.
  """
  @spec send(Conn.t(), error | [error], status :: non_neg_integer()) :: Conn.t()
        when error: map()
  def send(conn, error, status) when is_map(error),
    do: send(conn, [error], status)

  def send(conn, errors, status) when is_list(errors) do
    body = Jason.encode!(%{errors: errors})

    conn
    |> Conn.put_resp_content_type(@media_type)
    |> Conn.send_resp(status, body)
    |> Conn.halt()
  end
end
