defmodule SportipediaWeb.Catalog.Equipment.Apparatus.ArchiveApparatusEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Repo

  @moduletag :integration

  describe "POST archive-apparatus" do
    test "archives an apparatus and returns last known state when authenticated" do
      # First, create an apparatus through the proper command flow
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{
              "title" => "Vault",
              "slug" => "vault",
              "description" => "A gymnastics apparatus"
            })
          )
        )

      body = json_response(conn, 200)
      id = jsonapi_id(body)

      # Now archive it
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/archive-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{}, id))
        )

      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "type" => "apparatuses",
                 "attributes" => %{
                   "title" => "Vault",
                   "slug" => "vault",
                   "description" => "A gymnastics apparatus"
                 }
               }
             } = body

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
