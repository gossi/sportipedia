defmodule SportipediaWeb.Catalog.Athlete.Position.EditPositionEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position

  describe "POST /catalog/athlete/positions/edit-position" do
    test "edit-position returns 200 with the position", %{conn: conn} do
      catalog_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{title: "sample-title", slug: "sample-slug-#{UUID.uuid4()}"})
          )
        )

      catalog_body = json_response(catalog_conn, 200)
      id = jsonapi_id(catalog_body)

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{}, id))
        )

      body = json_response(conn, 200)

      assert jsonapi_id(body) == id
    end

    test "returns 403 when unauthenticated", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{}))
        )

      assert json_response(conn, 403)
    end
  end
end
