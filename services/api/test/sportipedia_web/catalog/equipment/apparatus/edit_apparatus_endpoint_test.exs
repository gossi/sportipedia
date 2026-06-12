defmodule SportipediaWeb.Catalog.Equipment.Apparatus.EditApparatusEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Repo

  describe "PATCH /catalog/equipment/apparatuses/:id/edit-apparatus" do
    test "edits an existing apparatus and returns 200", %{conn: conn} do
      # First, catalog an apparatus
      catalog_conn =
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

      catalog_body = json_response(catalog_conn, 201)
      apparatus_id = jsonapi_id(catalog_body)

      # Then, edit the apparatus
      edit_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> patch(
          "/catalog/equipment/apparatuses/#{apparatus_id}/edit-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{title: "Vault"}, apparatus_id))
        )

      body = json_response(edit_conn, 200)

      assert %{
               "data" => %{
                 "id" => ^apparatus_id,
                 "type" => "apparatuses",
                 "attributes" => %{
                   "title" => "Vault",
                   "slug" => "vaulting-table",
                   "description" => "A gymnastics vault"
                 }
               }
             } = body

      assert Repo.get(ApparatusReadModel, apparatus_id)
    end

    test "edits with only description", %{conn: conn} do
      catalog_conn =
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

      catalog_body = json_response(catalog_conn, 201)
      apparatus_id = jsonapi_id(catalog_body)

      edit_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> patch(
          "/catalog/equipment/apparatuses/#{apparatus_id}/edit-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{description: "Used for gymnastics"}, apparatus_id)
          )
        )

      body = json_response(edit_conn, 200)

      assert jsonapi_attr(body, "title") == "Parallel Bars"
      assert jsonapi_attr(body, "slug") == "parallel-bars"
      assert jsonapi_attr(body, "description") == "Used for gymnastics"
    end

    test "returns 200 when editing keeping the same slug", %{conn: conn} do
      # Catalog an apparatus
      catalog_conn =
        conn
        |> authenticate_conn()
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

      catalog_body = json_response(catalog_conn, 201)
      apparatus_id = jsonapi_id(catalog_body)

      # Edit the title, keeping the same slug — should succeed
      edit_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> patch(
          "/catalog/equipment/apparatuses/#{apparatus_id}/edit-apparatus",
          Jason.encode!(
            jsonapi_body("apparatuses", %{title: "Updated Vault", slug: "vaulting-table"}, apparatus_id)
          )
        )

      body = json_response(edit_conn, 200)
      assert jsonapi_attr(body, "title") == "Updated Vault"
      assert jsonapi_attr(body, "slug") == "vaulting-table"
    end

    test "returns 403 when unauthenticated" do
      conn =
        build_conn()
        |> api_conn()
        |> patch(
          "/catalog/equipment/apparatuses/some-id/edit-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{title: "Vault"}, "some-id"))
        )

      assert json_response(conn, 403)
    end

    test "returns 404 when apparatus does not exist", %{conn: conn} do
      non_existent_id = UUID.uuid4()

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> patch(
          "/catalog/equipment/apparatuses/#{non_existent_id}/edit-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{title: "Vault"}, non_existent_id))
        )

      assert json_response(conn, 404)
    end

    test "returns 422 when slug already exists", %{conn: conn} do
      # Catalog first apparatus
      first_conn =
        conn
        |> authenticate_conn()
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

      first_body = json_response(first_conn, 201)
      _first_id = jsonapi_id(first_body)

      # Catalog second apparatus
      second_conn =
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

      second_body = json_response(second_conn, 201)
      second_id = jsonapi_id(second_body)

      # Try to edit second apparatus to have the same slug as the first
      edit_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> patch(
          "/catalog/equipment/apparatuses/#{second_id}/edit-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{slug: "vaulting-table"}, second_id))
        )

      assert json_response(edit_conn, 422)
    end
  end
end
