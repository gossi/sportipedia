defmodule SportipediaWeb.Catalog.Equipment.Widget.ReadWidgetEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Widget
  alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel
  alias Sportipedia.TestSupport.Catalog.Equipment
  alias Sportipedia.TestSupport.Catalog.Equipment.WidgetFixtures

  describe "GET /catalog/equipment/widgets/:id_or_slug (read-widget)" do
    test "returns 200 with the widget when found", %{conn: conn} do
          {:ok, %{id: id}} = Equipment.new_widget(WidgetFixtures.classic_widget())

      conn =
        conn
        |> api_conn()
        |> get("/catalog/equipment/widgets/#{id}")

      body = json_response(conn, 200)

      assert jsonapi_id(body) == id
    end


    test "returns 404 when the widget does not exist", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> get("/catalog/equipment/widgets/#{UUID.uuid4()}")

      assert json_response(conn, 404)
    end

  end
end
