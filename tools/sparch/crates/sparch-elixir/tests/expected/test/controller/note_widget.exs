defmodule SportipediaWeb.Catalog.Equipment.Widget.NoteWidgetEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Widget
  alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel

  describe "POST /catalog/equipment/widgets/note-widget" do
    test "note-widget returns 204 for a valid payload", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/widgets/note-widget", Jason.encode!(jsonapi_body("widget", %{comment: "sample-comment"})))

      assert conn.status == 204
      assert conn.resp_body == ""
    end


    test "returns 403 when unauthenticated", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> post("/catalog/equipment/widgets/note-widget", Jason.encode!(jsonapi_body("widget", %{})))

      assert json_response(conn, 403)
    end

  end
end
