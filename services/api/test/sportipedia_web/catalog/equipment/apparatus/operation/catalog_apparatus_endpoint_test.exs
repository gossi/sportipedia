defmodule SportipediaWeb.Catalog.Equipment.Apparatus.CatalogApparatusEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel, as: Apparatus

  describe "POST /catalog/equipment/apparatuses/catalog-apparatus" do
    test "catalog-apparatus with valid params returns 200 and projects read model" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{
              "title" => "Vaulting Table",
              "slug" => "vaulting-table",
              "description" => "A gymnastics vault"
            })
          )
        )

      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "apparatuses",
                 "attributes" => %{
                   "title" => "Vaulting Table",
                   "slug" => "vaulting-table",
                   "description" => "A gymnastics vault"
                 }
               }
             } = body

      assert %Apparatus{} = Repo.get(Apparatus, id)
    end

    test "returns 403 when unauthenticated" do
      conn =
        build_conn()
        |> api_conn()
        |> post("/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{
              "title" => "Vaulting Table",
              "slug" => "vaulting-table"
            })
          )
        )

      assert json_response(conn, 403)
    end

    test "returns 422 when title is missing" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{
              "slug" => "vaulting-table"
            })
          )
        )

      assert json_response(conn, 422)
    end

    test "returns 422 when slug is missing" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{
              "title" => "Vaulting Table"
            })
          )
        )

      assert json_response(conn, 422)
    end

    test "returns 422 when slug already exists" do
      # First, create an apparatus
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{
              "title" => "Vaulting Table",
              "slug" => "vaulting-table"
            })
          )
        )

      assert json_response(conn, 200)

      # Try to create another with the same slug
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{
              "title" => "Another Apparatus",
              "slug" => "vaulting-table"
            })
          )
        )

      assert json_response(conn, 422)
    end
  end
end
