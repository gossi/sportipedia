defmodule SportipediaWeb.Catalog.Equipment.Apparatus.CatalogApparatusRequestTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel

  @moduletag :integration

  describe "POST catalog-apparatus" do
    test "successfully catalogs an apparatus and returns 201" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{
            title: "Vaulting Table",
            slug: "vaulting-table",
            description: "A gymnastics vault"
          }))
        )

      body = json_response(conn, 201)

      assert %{
               "data" => %{
                 "id" => _id,
                 "type" => "apparatuses",
                 "attributes" => %{
                   "title" => "Vaulting Table",
                   "slug" => "vaulting-table",
                   "description" => "A gymnastics vault"
                 }
               }
             } = body

      assert Repo.get(ApparatusReadModel, body["data"]["id"])
    end

    test "returns 403 when unauthenticated" do
      conn =
        build_conn()
        |> api_conn()
        |> post("/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{
            title: "Vaulting Table",
            slug: "vaulting-table",
            description: "A gymnastics vault"
          }))
        )

      json_response(conn, 403)
    end

    test "returns 422 when title is missing" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{
            slug: "vaulting-table",
            description: "A gymnastics vault"
          }))
        )

      json_response(conn, 422)
    end

    test "returns 422 when slug is missing" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{
            title: "Vaulting Table",
            description: "A gymnastics vault"
          }))
        )

      json_response(conn, 422)
    end
  end
end
