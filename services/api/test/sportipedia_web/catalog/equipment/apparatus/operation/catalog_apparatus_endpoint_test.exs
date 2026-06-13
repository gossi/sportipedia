defmodule SportipediaWeb.Catalog.Equipment.Apparatus.CatalogApparatusEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Repo
  alias SportipediaWeb.Catalog.Equipment.ApparatusView

  describe "POST /catalog/equipment/apparatuses/catalog-apparatus" do
    test "catalog-apparatus returns 201 with the cataloged apparatus", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{
              title: "Vaulting Table",
              slug: "vaulting-table",
              description: "A gymnastics vault"
            })
          )
        )

      body = json_response(conn, 201)

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "apparatuses",
                 "attributes" => %{
                   "title" => "Vaulting Table",
                   "slug" => "vaulting-table",
                   "description" => "A gymnastics vault"
                 },
                 "links" => %{
                   "self" => self_link
                 }
               }
             } = body

      assert is_binary(id)
      assert self_link =~ "/catalog/equipment/apparatuses/#{id}"
      assert Repo.get(ApparatusReadModel, id)
    end

    test "catalog-apparatus works without optional description", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{
              title: "Parallel Bars",
              slug: "parallel-bars"
            })
          )
        )

      body = json_response(conn, 201)

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "apparatuses",
                 "attributes" => %{
                   "title" => "Parallel Bars",
                   "slug" => "parallel-bars"
                 }
               }
             } = body

      assert Repo.get(ApparatusReadModel, id)
    end

    test "returns 403 when unauthenticated" do
      conn =
        build_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{
              title: "Vaulting Table",
              slug: "vaulting-table"
            })
          )
        )

      assert json_response(conn, 403)
    end

    test "returns 422 when title is missing", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{
              slug: "vaulting-table"
            })
          )
        )

      assert json_response(conn, 422)
    end

    test "returns 422 when slug is missing", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{
              title: "Vaulting Table"
            })
          )
        )

      assert json_response(conn, 422)
    end

    test "returns 422 when slug already exists", %{conn: conn} do
      # First, catalog an apparatus
      conn
      |> authenticate_conn()
      |> api_conn()
      |> post(
        "/catalog/equipment/apparatuses/catalog-apparatus",
        Jason.encode!(
          jsonapi_body("apparatuses", %{
            title: "Vaulting Table",
            slug: "vaulting-table",
            description: "A gymnastics vault"
          })
        )
      )

      # Then try to catalog another with the same slug
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/catalog-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{
              title: "Another Vault",
              slug: "vaulting-table"
            })
          )
        )

      assert json_response(conn, 422)
    end
  end
end
