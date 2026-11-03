defmodule SportipediaWeb.Catalog.Athlete.Position.ReadPositionEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel

  describe "GET /catalog/athlete/positions/:id_or_slug (read-position)" do
    test "returns 200 with the position when found", %{conn: conn} do
      {:ok, %{id: id}} =
        Position.catalog_position(%{title: "sample-title", slug: "sample-slug-#{UUID.uuid4()}"})

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/#{id}")

      body = json_response(conn, 200)

      assert jsonapi_id(body) == id
    end

    test "returns 404 when the position does not exist", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/#{UUID.uuid4()}")

      assert json_response(conn, 404)
    end
  end
end
