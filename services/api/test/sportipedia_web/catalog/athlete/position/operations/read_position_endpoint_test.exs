defmodule SportipediaWeb.Catalog.Athlete.Position.ReadPositionEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Equipment.Apparatus

  describe "GET /catalog/athlete/positions/:id_or_slug (read-position)" do
    test "returns 200 with the position when a guest reads it by id", %{conn: conn} do
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

    test "returns 200 with no equipment reference when the position has none", %{conn: conn} do
      slug = "ready-stance-#{UUID.uuid4()}"

      {:ok, created} =
        Position.catalog_position(%{
          title: "Ready Stance",
          slug: slug,
          description: "Athletic stance with knees slightly bent"
        })

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/#{slug}")

      body = json_response(conn, 200)

      assert jsonapi_id(body) == created.id
      assert jsonapi_attr(body, "title") == "Ready Stance"
      assert jsonapi_attr(body, "apparatusId") == nil
      assert jsonapi_attr(body, "instrumentId") == nil
    end

    test "returns 200 when the caller spells the slug in another case", %{conn: conn} do
      # The stored slug is canonical lowercase, so the read meets the caller
      # halfway: whatever case the address arrives in, the position answers.
      slug = "astronaut-position-#{UUID.uuid4()}"

      {:ok, created} = Position.catalog_position(%{title: "Astronaut", slug: slug})

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/#{String.upcase(slug)}")

      body = json_response(conn, 200)

      assert jsonapi_id(body) == created.id
      assert jsonapi_attr(body, "slug") == slug
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

    test "returns 404 to a guest for a position that left the catalog" do
      # `position-archived` is a delete: no row is left to read, so both ways of
      # addressing the position answer the same way. There is no archived flag to
      # report and no unarchive that would bring it back.
      slug = "lunge-position-#{UUID.uuid4()}"
      {:ok, created} = Position.catalog_position(%{title: "Lunge Position", slug: slug})

      assert :ok = Position.archive_position(created.id)

      for address <- [created.id, slug] do
        conn =
          build_conn()
          |> api_conn()
          |> get("/catalog/athlete/positions/#{address}")

        # The read's own not-found answer, not a routing miss: the fallback
        # renders this document only for `{:error, :not_found}`.
        assert %{"errors" => [%{"status" => 404, "title" => "Not found"}]} =
                 json_response(conn, 404)
      end
    end
  end
end
