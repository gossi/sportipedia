defmodule SportipediaWeb.Catalog.Athlete.Position.CatalogPositionEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  @moduletag :integration

  describe "POST /catalog/athlete/positions/catalog-position" do
    test "catalog-position returns 200 with the position", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(jsonapi_body("position", %{title: "Riding", slug: "riding"}))
        )

      body = json_response(conn, 200)

      assert jsonapi_type(body) == "position"
    end

    test "returns 403 when unauthenticated", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(jsonapi_body("position", %{}))
        )

      assert json_response(conn, 403)
    end
  end
end
