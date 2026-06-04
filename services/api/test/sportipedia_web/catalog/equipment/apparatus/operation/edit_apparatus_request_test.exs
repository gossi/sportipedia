defmodule SportipediaWeb.Catalog.Equipment.Apparatus.EditApparatusRequestTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Repo

  describe "PATCH edit-apparatus" do
    test "successfully edits an apparatus with partial update", %{conn: conn} do
      apparatus = %ApparatusReadModel{
        id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }
      Repo.insert!(apparatus)

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> patch("/catalog/equipment/apparatuses/edit-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{title: "Vault"}, apparatus.id))
        )

      body = json_response(conn, 200)

      assert jsonapi_id(body) == apparatus.id
      assert jsonapi_type(body) == "apparatuses"
      assert jsonapi_attr(body, "title") == "Vault"
      assert jsonapi_attr(body, "slug") == "vaulting-table"
      assert jsonapi_attr(body, "description") == "A gymnastics vault"
    end

    test "returns 403 when unauthenticated", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> patch("/catalog/equipment/apparatuses/edit-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{title: "Vault"}, "d290f1ee-6c54-4b01-90e6-d701748f0851"))
        )

      json_response(conn, 403)
    end

    @tag :notfound
    test "returns 404 when apparatus doesn't exist", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> patch("/catalog/equipment/apparatuses/edit-apparatus",
          Jason.encode!(jsonapi_body("apparatuses", %{title: "Vault"}, "d290f1ee-6c54-4b01-90e6-d701748f0851"))
        )

      json_response(conn, 404)
    end
  end
end
