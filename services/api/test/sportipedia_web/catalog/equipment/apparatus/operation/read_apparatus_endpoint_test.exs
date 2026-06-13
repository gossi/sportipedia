defmodule SportipediaWeb.Catalog.Equipment.Apparatus.ReadApparatusEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel

  describe "GET /catalog/equipment/apparatuses/:id_or_slug (read-apparatus)" do
    test "returns 200 with apparatus when found by id", %{conn: conn} do
      # First, catalog an apparatus
      {:ok, %ApparatusReadModel{id: id}} =
        Apparatus.catalog_apparatus(%{
          title: "Vaulting Table",
          slug: "vaulting-table",
          description: "A gymnastics vault"
        })

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses/#{id}")

      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "type" => "apparatuses",
                 "attributes" => %{
                   "title" => "Vaulting Table",
                   "slug" => "vaulting-table",
                   "description" => "A gymnastics vault"
                 }
               }
             } = body
    end

    test "returns 200 with apparatus when found by slug", %{conn: conn} do
      {:ok, %ApparatusReadModel{id: id}} =
        Apparatus.catalog_apparatus(%{
          title: "Parallel Bars",
          slug: "parallel-bars",
          description: "A gymnastics apparatus"
        })

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses/parallel-bars")

      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "type" => "apparatuses",
                 "attributes" => %{
                   "title" => "Parallel Bars",
                   "slug" => "parallel-bars",
                   "description" => "A gymnastics apparatus"
                 }
               }
             } = body
    end

    test "returns 404 when apparatus not found", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses/non-existent-slug")

      assert json_response(conn, 404)
    end

    test "returns 200 for unauthenticated (guest) request", %{conn: conn} do
      {:ok, %ApparatusReadModel{id: id}} =
        Apparatus.catalog_apparatus(%{
          title: "Rings",
          slug: "rings",
          description: "Still rings"
        })

      conn =
        conn
        |> api_conn()
        |> get("/catalog/equipment/apparatuses/#{id}")

      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "type" => "apparatuses",
                 "attributes" => %{
                   "title" => "Rings",
                   "slug" => "rings"
                 }
               }
             } = body
    end
  end
end
