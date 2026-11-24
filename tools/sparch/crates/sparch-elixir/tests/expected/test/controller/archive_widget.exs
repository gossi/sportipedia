defmodule SportipediaWeb.Catalog.Equipment.Widget.ArchiveWidgetEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Widget
  alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel

  describe "POST /catalog/equipment/widgets/archive-widget" do
    test "archive-widget returns 204 for a cataloged widget", %{conn: conn} do
      {:ok, %{id: id}} = Widget.create_widget(%{label: "Pommel", slug: "pommel-horse", title: "Pommel Horse"})

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/widgets/archive-widget", Jason.encode!(jsonapi_body("widget", %{}, id)))

      assert conn.status == 204
      assert conn.resp_body == ""
    end


    test "returns 404 for an unknown id", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/widgets/archive-widget", Jason.encode!(jsonapi_body("widget", %{}, UUID.uuid4())))

      assert json_response(conn, 404)
    end


    test "returns 403 when unauthenticated", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> post("/catalog/equipment/widgets/archive-widget", Jason.encode!(jsonapi_body("widget", %{})))

      assert json_response(conn, 403)
    end

  end
end
