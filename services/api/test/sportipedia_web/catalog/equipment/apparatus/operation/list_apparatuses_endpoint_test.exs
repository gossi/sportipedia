defmodule SportipediaWeb.Catalog.Equipment.Apparatus.ListApparatusesEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel, as: Apparatus
  alias Sportipedia.Catalog.Repo

  @moduletag :integration

  describe "GET /catalog/equipment/apparatuses (list_apparatuses)" do
    setup do
      attrs_list = [
        %{
          id: Ecto.UUID.generate(),
          title: "Vault",
          slug: "vault",
          description: "A gymnastics vault"
        },
        %{
          id: Ecto.UUID.generate(),
          title: "Balance Beam",
          slug: "balance-beam",
          description: "A gymnastics beam"
        },
        %{
          id: Ecto.UUID.generate(),
          title: "Parallel Bars",
          slug: "parallel-bars",
          description: nil
        }
      ]

      for attrs <- attrs_list do
        %Apparatus{}
        |> Apparatus.insert_changeset(attrs)
        |> Repo.insert!()
      end

      %{apparatuses: attrs_list}
    end

    test "returns 200 with JSON:API collection of all apparatuses", %{apparatuses: apparatuses} do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses")

      body = json_response(conn, 200)

      assert %{"data" => data} = body
      assert is_list(data)
      assert length(data) == 3

      ids = Enum.map(data, & &1["id"])
      expected_ids = Enum.map(apparatuses, & &1.id)
      assert Enum.sort(ids) == Enum.sort(expected_ids)

      for item <- data do
        assert item["type"] == "apparatuses"
        assert %{"title" => _, "slug" => _} = item["attributes"]
      end
    end

    test "returns 200 for unauthenticated (guest) requests" do
      conn =
        build_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses")

      assert json_response(conn, 200)
    end

    test "returns empty collection when no apparatuses exist" do
      # Delete all apparatuses
      Repo.delete_all(Apparatus)

      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses")

      body = json_response(conn, 200)
      assert %{"data" => []} = body
    end
  end
end
