defmodule SportipediaWeb.Catalog.Athlete.Position.ReadPositionEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Equipment.Apparatus

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
      assert jsonapi_type(body) == "position"
    end

    test "returns 200 for a guest reading by slug, with the equipment reference", %{conn: conn} do
      {:ok, apparatus} = Apparatus.catalog_apparatus(%{title: "Beam", slug: "beam"})
      slug = "l-sit-#{UUID.uuid4()}"

      {:ok, created} =
        Position.catalog_position(%{
          title: "L-Sit",
          slug: slug,
          description: "Support hold with legs at ninety degrees",
          apparatusId: apparatus.id
        })

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/#{slug}")

      body = json_response(conn, 200)

      assert jsonapi_id(body) == created.id
      assert jsonapi_attr(body, "title") == "L-Sit"
      assert jsonapi_attr(body, "slug") == slug
      assert jsonapi_attr(body, "description") == "Support hold with legs at ninety degrees"
      assert jsonapi_attr(body, "apparatusId") == apparatus.id
      assert jsonapi_attr(body, "instrumentId") == nil
    end

    test "returns 404 when the position does not exist", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/#{UUID.uuid4()}")

      assert json_response(conn, 404)
    end

    test "returns 404 for a slug that no position holds", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/nobody-holds-this-#{UUID.uuid4()}")

      assert json_response(conn, 404)
    end
  end
end
