defmodule Sportipedia.Auth.Plug.SystemAuth do
  import Plug.Conn
  @max_skew 300

  defp secret(), do: System.fetch_env!("AUTH_API_SECRET")
  def init(opts), do: opts

  def call(conn, _opts) do
    with [timestamp] <- get_req_header(conn, "x-timestamp"),
         [signature] <- get_req_header(conn, "x-signature"),
         true <- valid_timestamp?(timestamp),
         body when is_binary(body) <- conn.assigns[:raw_body] || "",
         true <- valid_signature?(timestamp, body, signature) do
      assign(conn, :raw_body, body)
    else
      _ ->
        conn
        |> send_resp(401, "Invalid HMAC")
        |> halt()
    end
  end

  defp valid_timestamp?(timestamp) do
    case Integer.parse(timestamp) do
      {ts, ""} ->
        now = System.system_time(:second)
        abs(now - ts) <= @max_skew

      _ ->
        false
    end
  end

  defp valid_signature?(timestamp, body, sig) do
    data = "#{timestamp}.#{body}"

    expected =
      :crypto.mac(:hmac, :sha256, secret(), data)
      |> Base.encode16(case: :lower)

    Plug.Crypto.secure_compare(expected, sig)
  end
end
