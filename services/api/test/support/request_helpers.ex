defmodule SportipediaWeb.RequestHelpers do
  import Plug.Conn

  def authenticate_conn(conn, user \\ %{id: UUID.uuid4()}) do
    assign(conn, :user, user)
  end

  def api_conn(conn) do
    put_req_header(conn, "content-type", "application/vnd.api+json")
  end

  def jsonapi_body(type, %{} = attrs) do
    %{"data" => %{"type" => type, "attributes" => attrs}}
  end

  def jsonapi_body(type, id) do
    %{"data" => %{"type" => type, "id" => id, "attributes" => %{}}}
  end

  def jsonapi_body(type, %{} = attrs, id) do
    %{"data" => %{"type" => type, "id" => id, "attributes" => attrs}}
  end

  def jsonapi_id(response), do: get_data(response)["id"]
  def jsonapi_type(response), do: get_data(response)["type"]
  def jsonapi_attrs(response), do: get_data(response)["attributes"]
  def jsonapi_attr(response, field), do: get_data(response)["attributes"][field]

  defp get_data(%{"data" => _} = response), do: response["data"]
  defp get_data(%{} = response), do: response
end
