defmodule SportipediaWeb.Catalog.Athlete.Position.EditPositionEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Equipment.Apparatus

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

    test "edit-position answers with the title the patch left behind", %{conn: conn} do
      catalog_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{title: "Old Title", slug: "carried-#{UUID.uuid4()}"})
          )
        )

      id = jsonapi_id(json_response(catalog_conn, 200))

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{title: "New Title"}, id))
        )

      body = json_response(conn, 200)

      assert jsonapi_attr(body, "title") == "New Title"
    end

    # Same camel-case attribute seam as catalog-position (see
    # CatalogPositionEndpointTest): the edit path re-uses it, one case suffices.
    test "edit-position carries an apparatus reference through HTTP", %{conn: conn} do
      assert {:ok, apparatus} =
               Apparatus.catalog_apparatus(%{
                 title: "Parallel Bars",
                 slug: "parallel-bars-#{UUID.uuid4()}"
               })

      catalog_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{title: "sample-title", slug: "unbound-#{UUID.uuid4()}"})
          )
        )

      id = jsonapi_id(json_response(catalog_conn, 200))

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{apparatusId: apparatus.id}, id))
        )

      body = json_response(conn, 200)

      assert jsonapi_attr(body, "apparatusId") == apparatus.id
    end

    test "returns 404 for a position the catalog does not hold", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{title: "New Title"}, UUID.uuid4()))
        )

      assert json_response(conn, 404)
    end

    test "returns 404 for an address that names no position", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{title: "New Title"}, "pos-456"))
        )

      assert json_response(conn, 404)
    end

    test "returns 422 for a patch that names no position", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{title: "New Title"}))
        )

      assert json_response(conn, 422)
    end

    test "returns 404 for a position that left the catalog", %{conn: conn} do
      catalog_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{title: "sample-title", slug: "departed-#{UUID.uuid4()}"})
          )
        )

      id = jsonapi_id(json_response(catalog_conn, 200))
      assert :ok = Position.archive_position(id)

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{title: "New Title"}, id))
        )

      assert json_response(conn, 404)
    end

    test "returns 422 for a slug another position holds", %{conn: conn} do
      held_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{title: "sample-title", slug: "held-#{UUID.uuid4()}"})
          )
        )

      held_body = json_response(held_conn, 200)
      held_slug = jsonapi_attr(held_body, "slug")

      edited_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{title: "sample-title", slug: "taking-#{UUID.uuid4()}"})
          )
        )

      id = jsonapi_id(json_response(edited_conn, 200))

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{slug: held_slug}, id))
        )

      assert json_response(conn, 422)
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
