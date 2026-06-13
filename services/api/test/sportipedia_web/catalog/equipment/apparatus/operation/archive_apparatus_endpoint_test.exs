defmodule SportipediaWeb.Catalog.Equipment.Apparatus.ArchiveApparatusEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Repo

  describe "POST /catalog/equipment/apparatuses/archive-apparatus" do
    test "archives an existing apparatus and returns 204", %{conn: conn} do
      # First, catalog an apparatus
      catalog_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{
              title: "Balance Beam",
              slug: "balance-beam",
              description: "A gymnastics beam"
            })
          )
        )

      catalog_body = json_response(catalog_conn, 201)
      apparatus_id = jsonapi_id(catalog_body)

      # Then, archive the apparatus
      archive_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/archive-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", apparatus_id))
        )

      assert archive_conn.status == 204
      assert archive_conn.resp_body == ""

      # The read model should be deleted after archiving
      refute Repo.get(ApparatusReadModel, apparatus_id)
    end

    test "returns 403 when unauthenticated" do
      conn =
        build_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/archive-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", UUID.uuid4()))
        )

      assert json_response(conn, 403)
    end

    test "returns 404 when apparatus does not exist (idempotent archive)", %{conn: conn} do
      non_existent_id = UUID.uuid4()

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/archive-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", non_existent_id))
        )

      body = json_response(conn, 404)

      assert conn.status == 404
      assert %{"errors" => [%{"status" => 404, "title" => "Not found"}]} = body
    end
  end
end
