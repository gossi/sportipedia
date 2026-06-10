defmodule SportipediaWeb.Catalog.Equipment.Apparatus.EditApparatusEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus, as: ApparatusAPI

  @moduletag :integration

  describe "POST /catalog/equipment/apparatuses/edit-apparatus" do
    test "edits an existing apparatus with partial fields", %{conn: conn} do
      {:ok, created} =
        ApparatusAPI.catalog_apparatus(%{
          title: "Vaulting Table",
          slug: "vaulting-table",
          description: "A gymnastics vault"
        })

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/edit-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{title: "Vault"}, created.id))
        )

      body = json_response(conn, 200)

      assert jsonapi_id(body) == created.id
      assert jsonapi_type(body) == "apparatuses"
      assert jsonapi_attr(body, "title") == "Vault"
      assert jsonapi_attr(body, "slug") == "vaulting-table"
      assert jsonapi_attr(body, "description") == "A gymnastics vault"
    end

    test "returns 403 when unauthenticated", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/edit-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{title: "Vault"}, "some-id"))
        )

      assert json_response(conn, 403)
    end

    test "returns 404 when apparatus does not exist", %{conn: conn} do
      id = UUID.uuid4()

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/edit-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{title: "Vault"}, id))
        )

      assert json_response(conn, 404)
    end

    test "returns 422 when title has invalid format", %{conn: conn} do
      {:ok, created} =
        ApparatusAPI.catalog_apparatus(%{
          title: "Vaulting Table",
          slug: "vaulting-table",
          description: "A gymnastics vault"
        })

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/apparatuses/edit-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{title: ""}, created.id))
        )

      assert json_response(conn, 422)
    end
  end
end
