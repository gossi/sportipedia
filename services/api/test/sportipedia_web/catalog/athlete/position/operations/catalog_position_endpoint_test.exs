defmodule SportipediaWeb.Catalog.Athlete.Position.CatalogPositionEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Equipment.Apparatus

  describe "POST /catalog/athlete/positions/catalog-position" do
    test "catalog-position returns 200 with the position", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{title: "sample-title", slug: "sample-slug-#{UUID.uuid4()}"})
          )
        )

      body = json_response(conn, 200)

      assert jsonapi_type(body) == "position"
    end

    # Spec scenario "Catalog a position with apparatus reference" over HTTP: the
    # :api pipeline's JSONAPI.UnderscoreParameters rewrites the camel-case
    # `apparatusId` attribute before ExConstructor maps it onto the command —
    # a seam only this round-trip proves. A broken seam catalogs the position
    # without the reference and still answers 200, so the rendered attribute
    # must be asserted, not just the status.
    test "catalogs a position with an apparatus reference carried as a camel-case attribute", %{
      conn: conn
    } do
      assert {:ok, apparatus} =
               Apparatus.catalog_apparatus(%{
                 title: "Starting Blocks",
                 slug: "starting-blocks-#{UUID.uuid4()}"
               })

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{
              title: "Starting Block Position",
              slug: "starting-block-position-#{UUID.uuid4()}",
              apparatusId: apparatus.id
            })
          )
        )

      body = json_response(conn, 200)

      assert jsonapi_attr(body, "apparatusId") == apparatus.id
    end

    # If the camel-case attribute ever arrives nil, `allow_nil` skips the
    # existence check and the position catalogs without a reference — so this
    # must answer 422 on the `apparatusId` field, not 200.
    test "returns 422 on the apparatusId field when the referenced apparatus does not exist", %{
      conn: conn
    } do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{
              title: "Unknown Apparatus Position",
              slug: "unknown-apparatus-position-#{UUID.uuid4()}",
              apparatusId: UUID.uuid4()
            })
          )
        )

      body = json_response(conn, 422)

      assert Enum.any?(body["errors"], fn error ->
               get_in(error, ["source", "pointer"]) == "/data/attributes/apparatusId"
             end)
    end

    test "returns 422 when the command validation fails", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(jsonapi_body("position", %{title: "Missing Slug Position"}))
        )

      assert json_response(conn, 422)
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
