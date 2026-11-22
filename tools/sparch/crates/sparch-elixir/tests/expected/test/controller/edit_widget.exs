defmodule SportipediaWeb.Catalog.Equipment.Widget.EditWidgetEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Widget

  describe "POST /catalog/equipment/widgets/edit-widget" do
    test "edit-widget returns 200 with the widget", %{conn: conn} do
      catalog_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/widgets/create-widget", Jason.encode!(jsonapi_body("widget", %{label: "Pommel", slug: "pommel-horse", title: "Pommel Horse"})))

      catalog_body = json_response(catalog_conn, 200)
      id = jsonapi_id(catalog_body)

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/widgets/edit-widget", Jason.encode!(jsonapi_body("widget", %{id: "{{ generated }}", label: "Vaulting", slug: "vaulting-table", title: "Vaulting Table"}, id)))

      body = json_response(conn, 200)

      assert jsonapi_id(body) == id
    end


    test "returns 403 when unauthenticated", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> post("/catalog/equipment/widgets/edit-widget", Jason.encode!(jsonapi_body("widget", %{})))

      assert json_response(conn, 403)
    end

  end
end
