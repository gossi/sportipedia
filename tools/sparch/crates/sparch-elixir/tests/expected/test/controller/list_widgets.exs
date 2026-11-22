defmodule SportipediaWeb.Catalog.Equipment.Widget.ListWidgetsEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Widget
  alias Sportipedia.Catalog.Equipment.Widget.WidgetReadModel
  alias Sportipedia.TestSupport.Catalog.Equipment
  alias Sportipedia.TestSupport.Catalog.Equipment.WidgetFixtures

  describe "GET /catalog/equipment/widgets (list-widgets)" do
    test "returns 200 with a collection of widgets", %{conn: conn} do
          {:ok, _} = Equipment.new_widgets(WidgetFixtures.widgets())

      conn =
        conn
        |> api_conn()
        |> get("/catalog/equipment/widgets")

      body = json_response(conn, 200)

      assert is_list(body["data"])
    end

  end
end
