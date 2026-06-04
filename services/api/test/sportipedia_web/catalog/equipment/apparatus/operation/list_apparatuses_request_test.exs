defmodule SportipediaWeb.Catalog.Equipment.Apparatus.ListApparatusesRequestTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias Sportipedia.Catalog.Repo

  describe "GET list_apparatuses" do
    test "returns 200 OK with apparatuses list" do
      Repo.insert!(%ApparatusReadModel{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      })

      Repo.insert!(%ApparatusReadModel{
        id: UUID.uuid4(),
        title: "Balance Beam",
        slug: "balance-beam",
        description: nil
      })

      conn =
        build_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses")

      body = json_response(conn, 200)

      assert %{"data" => data, "links" => _, "included" => _} = body
      assert length(data) == 2

      titles = Enum.map(data, fn item -> item["attributes"]["title"] end) |> Enum.sort()
      assert titles == ["Balance Beam", "Vaulting Table"]

      slugs = Enum.map(data, fn item -> item["attributes"]["slug"] end) |> Enum.sort()
      assert slugs == ["balance-beam", "vaulting-table"]

      assert Enum.all?(data, fn item ->
        item["type"] == "apparatuses" && item["id"] != nil
      end)
    end

    test "returns 200 OK for unauthenticated (guest) request" do
      Repo.insert!(%ApparatusReadModel{
        id: UUID.uuid4(),
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: nil
      })

      conn =
        build_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses")

      body = json_response(conn, 200)

      assert length(body["data"]) == 1
    end

    test "returns 200 OK with empty list when no apparatuses exist" do
      conn =
        build_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses")

      body = json_response(conn, 200)

      assert body["data"] == []
    end
  end
end
