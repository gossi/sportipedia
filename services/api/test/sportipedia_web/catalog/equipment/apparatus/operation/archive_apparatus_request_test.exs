defmodule SportipediaWeb.Catalog.Equipment.Apparatus.Operation.ArchiveApparatusRequestTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Repo

  @moduletag :integration

  describe "POST archive-apparatus" do
    test "archives an apparatus when authenticated" do
      id = UUID.uuid4()

      Repo.insert!(%ApparatusReadModel{
        id: id,
        title: "Balance Beam",
        slug: "balance-beam",
        description: "A balance beam"
      })

      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/archive-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{}, id))
        )

      assert conn.status == 204
      refute Repo.get(ApparatusReadModel, id)
    end

    test "returns 403 when unauthenticated" do
      conn =
        build_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/archive-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{}, UUID.uuid4()))
        )

      assert json_response(conn, 403)
    end

    test "returns 404 when apparatus not found" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/archive-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{}, UUID.uuid4()))
        )

      assert json_response(conn, 404)
    end
  end
end
