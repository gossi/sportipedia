defmodule SportipediaWeb.Catalog.Equipment.Apparatus.ArchiveApparatusEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Repo

  describe "DELETE /catalog/equipment/apparatuses/:id/archive-apparatus" do
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
        |> delete("/catalog/equipment/apparatuses/#{apparatus_id}/archive-apparatus")

      assert archive_conn.status == 204
      assert archive_conn.resp_body == ""

      # The read model should be deleted after archiving
      refute Repo.get(ApparatusReadModel, apparatus_id)
    end

    test "returns 403 when unauthenticated" do
      conn =
        build_conn()
        |> api_conn()
        |> delete("/catalog/equipment/apparatuses/some-id/archive-apparatus")

      assert json_response(conn, 403)
    end

    test "returns 204 when apparatus does not exist (idempotent archive)", %{conn: conn} do
      non_existent_id = UUID.uuid4()

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> delete("/catalog/equipment/apparatuses/#{non_existent_id}/archive-apparatus")

      assert conn.status == 204
      assert conn.resp_body == ""
    end
  end
end
