defmodule SportipediaWeb.Catalog.Athlete.Position.ArchivePositionEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel

  describe "POST /catalog/athlete/positions/archive-position" do
    test "archive-position returns 204 for a cataloged position", %{conn: conn} do
      {:ok, %{id: id}} =
        Position.catalog_position(%{title: "sample-title", slug: "sample-slug-#{UUID.uuid4()}"})

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/archive-position",
          Jason.encode!(jsonapi_body("position", %{}, id))
        )

      assert conn.status == 204
      assert conn.resp_body == ""
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/archive-position",
          Jason.encode!(jsonapi_body("position", %{}, UUID.uuid4()))
        )

      assert json_response(conn, 404)
    end

    test "returns 403 when unauthenticated", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/archive-position",
          Jason.encode!(jsonapi_body("position", %{}))
        )

      assert json_response(conn, 403)
    end
  end
end
