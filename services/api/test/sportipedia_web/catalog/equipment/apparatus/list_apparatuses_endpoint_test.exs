defmodule SportipediaWeb.Catalog.Equipment.Apparatus.ListApparatusesEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel

  describe "GET /catalog/equipment/apparatuses (list-apparatuses)" do
    test "returns 200 with a collection of apparatuses", %{conn: conn} do
      {:ok, %ApparatusReadModel{id: id1}} =
        Apparatus.catalog_apparatus(%{title: "Vaulting Table", slug: "vaulting-table"})

      {:ok, %ApparatusReadModel{id: id2}} =
        Apparatus.catalog_apparatus(%{title: "Pommel Horse", slug: "pommel-horse"})

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses")

      body = json_response(conn, 200)

      assert %{"data" => data} = body
      assert is_list(data)
      assert length(data) == 2

      ids = Enum.map(data, & &1["id"])
      assert id1 in ids
      assert id2 in ids

      for item <- data do
        assert item["type"] == "apparatuses"
        assert %{"title" => _, "slug" => _} = item["attributes"]
      end
    end

    test "returns 200 for unauthenticated (guest) request", %{conn: conn} do
      {:ok, %ApparatusReadModel{id: id}} =
        Apparatus.catalog_apparatus(%{title: "Rings", slug: "rings"})

      conn =
        conn
        |> api_conn()
        |> get("/catalog/equipment/apparatuses")

      body = json_response(conn, 200)

      assert %{"data" => data} = body
      assert is_list(data)
      assert length(data) == 1
      assert hd(data)["id"] == id
      assert hd(data)["type"] == "apparatuses"
    end

    test "returns 200 with empty data when no apparatuses exist", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses")

      body = json_response(conn, 200)

      assert %{"data" => []} = body
    end
  end
end
