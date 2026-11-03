defmodule SportipediaWeb.Catalog.Athlete.Position.ListPositionsEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel

  describe "GET /catalog/athlete/positions (list-positions)" do
    test "returns 200 with a collection of positions", %{conn: conn} do
      {:ok, _} =
        Position.catalog_position(%{title: "sample-title", slug: "sample-slug-#{UUID.uuid4()}"})

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions")

      body = json_response(conn, 200)

      assert is_list(body["data"])
    end
  end
end
