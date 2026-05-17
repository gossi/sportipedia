defmodule SportipediaWeb.RequestHelpers do
  import Plug.Conn

  def authenticate_conn(conn, user \\ %{id: UUID.uuid4()}) do
    assign(conn, :user, user)
  end

  def api_conn(conn) do
    put_req_header(conn, "content-type", "application/vnd.api+json")
  end

  def jsonapi_body(type, attrs) do
    %{"data" => %{"type" => type, "attributes" => attrs}}
  end

  def jsonapi_body(type, attrs, id) do
    %{"data" => %{"type" => type, "id" => id, "attributes" => attrs}}
  end

  def jsonapi_id(response), do: response["data"]["id"]
  def jsonapi_type(response), do: response["data"]["type"]
  def jsonapi_attrs(response), do: response["data"]["attributes"]
  def jsonapi_attr(response, field), do: response["data"]["attributes"][field]
end
