defmodule SportipediaWeb.Catalog.Equipment.Widget.CreateWidgetEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Widget

  describe "POST /catalog/equipment/widgets/create-widget" do
    test "create-widget returns 200 with the widget", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/widgets/create-widget", Jason.encode!(jsonapi_body("widget", %{label: "Pommel", slug: "pommel-horse", title: "Pommel Horse"})))

      body = json_response(conn, 200)

      assert jsonapi_type(body) == "widget"
    end


    test "returns 403 when unauthenticated", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> post("/catalog/equipment/widgets/create-widget", Jason.encode!(jsonapi_body("widget", %{})))

      assert json_response(conn, 403)
    end

  end
end
