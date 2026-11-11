defmodule SportipediaWeb.Catalog.Athlete.Position.ReadPositionEndpointTest do
  use SportipediaWeb.ConnCase
  @moduletag :integration

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.TestSupport.Catalog.Athlete
  alias Sportipedia.TestSupport.Catalog.Athlete.PositionFixtures

  describe "GET /catalog/athlete/positions/:id_or_slug (read-position)" do
    test "returns 200 with the position when found", %{conn: conn} do
      {:ok, %{id: id}} = Athlete.new_position(PositionFixtures.unicycle_riding())

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/#{id}")

      body = json_response(conn, 200)

      assert jsonapi_id(body) == id
    end

    test "returns 200 with the canonical lookup path as its slug when read by an encoded compound slug",
         %{conn: conn} do
      {:ok, position} = Athlete.new_position(PositionFixtures.gymnastics_long_hang())

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/horizontal-bar%2Flong-hang")

      body = json_response(conn, 200)

      assert jsonapi_id(body) == position.id
      assert jsonapi_attr(body, "slug") == "horizontal-bar/long-hang"
      refute Map.has_key?(jsonapi_attrs(body), "raw_slug")
    end

    test "returns 200 with the bare lookup path as its slug when read by its bare slug",
         %{conn: conn} do
      {:ok, position} = Athlete.new_position(PositionFixtures.ready_stance())

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/ready-stance")

      body = json_response(conn, 200)

      assert jsonapi_id(body) == position.id
      assert jsonapi_attr(body, "slug") == "ready-stance"
      refute Map.has_key?(jsonapi_attrs(body), "raw_slug")
    end

    test "returns 404 when the position does not exist", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/#{UUID.uuid4()}")

      assert json_response(conn, 404)
    end

    test "returns 404 when read by the raw slug of a cataloged position", %{conn: conn} do
      {:ok, _position} = Athlete.new_position(PositionFixtures.gymnastics_long_hang())

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/long-hang")

      assert json_response(conn, 404)
    end

    test "returns 404 when the position was archived", %{conn: conn} do
      {:ok, position} =
        Position.catalog_position(%{title: "Lunge Position", slug: "lunge-position"})

      :ok = Position.archive_position(position.id)

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/#{position.id}")

      assert json_response(conn, 404)
    end
  end
end
