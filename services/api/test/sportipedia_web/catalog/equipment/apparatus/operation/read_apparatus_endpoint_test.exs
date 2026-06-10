defmodule SportipediaWeb.Catalog.Equipment.Apparatus.ReadApparatusEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel, as: Apparatus

  describe "GET /catalog/equipment/apparatuses/:id (read-apparatus)" do
    setup do
      attrs = %{
        id: Ecto.UUID.generate(),
        title: "Vault",
        slug: "vault",
        description: "A gymnastics vault"
      }

      %Apparatus{}
      |> Apparatus.insert_changeset(attrs)
      |> Repo.insert!()

      %{attrs: attrs}
    end

    test "returns 200 with apparatus when found by id", %{attrs: attrs} do
      conn =
        build_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses/#{attrs.id}")

      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "apparatuses",
                 "attributes" => %{
                   "title" => "Vault",
                   "slug" => "vault",
                   "description" => "A gymnastics vault"
                 }
               }
             } = body

      assert id == attrs.id
    end

    test "returns 200 with apparatus when found by slug", %{attrs: attrs} do
      conn =
        build_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses/#{attrs.slug}")

      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "apparatuses",
                 "attributes" => %{
                   "title" => "Vault",
                   "slug" => "vault"
                 }
               }
             } = body

      assert id == attrs.id
    end

    test "returns 404 when apparatus not found" do
      conn =
        build_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses/#{Ecto.UUID.generate()}")

      assert json_response(conn, 404)
    end

    test "returns 200 when unauthenticated (guest access allowed)" do
      # Create apparatus in setup, just make request without authenticate_conn
      conn =
        build_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses/vault")

      assert json_response(conn, 200)
    end
  end
end
