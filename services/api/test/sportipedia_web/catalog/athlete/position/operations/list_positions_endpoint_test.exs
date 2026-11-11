defmodule SportipediaWeb.Catalog.Athlete.Position.ListPositionsEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.TestSupport.Catalog.Athlete
  alias Sportipedia.TestSupport.Catalog.Athlete.PositionFixtures

  @moduletag :integration

  describe "GET /catalog/athlete/positions (list-positions)" do
    test "returns 200 with a collection of positions", %{conn: conn} do
      Athlete.new_positions(PositionFixtures.positions())

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions")

      body = json_response(conn, 200)

      assert is_list(body["data"])
    end

    test "returns 200 publishing the canonical lookup path as the position slug", %{conn: conn} do
      seeded = Athlete.new_positions(PositionFixtures.positions())

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions?sort=title")

      body = json_response(conn, 200)
      attributes = Enum.map(body["data"], & &1["attributes"])

      assert Enum.map(attributes, & &1["slug"]) ==
               seeded |> Enum.sort_by(& &1.title) |> Enum.map(& &1.slug)

      refute Enum.any?(attributes, &Map.has_key?(&1, "raw_slug"))
    end

    test "returns 200 sorting the collection by the slug it publishes, the canonical path", %{
      conn: conn
    } do
      seeded = Athlete.new_positions(PositionFixtures.positions())

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions?sort=slug")

      body = json_response(conn, 200)

      assert Enum.map(body["data"], & &1["attributes"]["slug"]) ==
               seeded |> Enum.sort_by(& &1.slug) |> Enum.map(& &1.slug)
    end

    test "returns 200 with only the positions whose title partially matches the filter", %{
      conn: conn
    } do
      seeded = Athlete.new_positions(PositionFixtures.positions())

      Athlete.new_position(
        struct!(PositionFixtures.unicycle_riding(),
          id: UUID.uuid4(),
          title: "Athletic Stance",
          raw_slug: "athletic-stance",
          slug: "athletic-stance"
        )
      )

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions?filter[title]=STANCE")

      body = json_response(conn, 200)
      titles = Enum.map(body["data"], & &1["attributes"]["title"])

      matching =
        seeded |> Enum.filter(&(&1.title |> String.downcase() |> String.contains?("stance")))

      assert titles |> Enum.sort() ==
               Enum.sort(["Athletic Stance" | Enum.map(matching, & &1.title)])

      assert Enum.all?(titles, &(&1 |> String.downcase() |> String.contains?("stance")))
    end

    test "returns 200 with the requested page of the catalogued positions", %{conn: conn} do
      Athlete.new_positions(paged_positions(25))

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/athlete/positions?sort=title&page[number]=2&page[size]=10")

      body = json_response(conn, 200)

      assert Enum.map(body["data"], & &1["attributes"]["title"]) ==
               Enum.map(11..20, &paging_title/1)
    end

    test "returns 200 to a guest, who may read the whole catalog", %{conn: conn} do
      {:ok, %PositionReadModel{} = seeded} =
        Athlete.new_position(PositionFixtures.unicycle_riding())

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions")

      body = json_response(conn, 200)

      assert [resource] = body["data"]
      assert resource["id"] == seeded.id
      assert resource["attributes"]["title"] == seeded.title
      assert resource["attributes"]["slug"] == seeded.slug
    end
  end

  # Seeding stays on the model's fixtures: the fixture carries the row's data,
  # the page walk only names the title and canonical path each position needs.
  defp paged_positions(count) do
    fixtures = PositionFixtures.positions()

    Enum.map(1..count, fn index ->
      struct!(Enum.at(fixtures, rem(index - 1, length(fixtures))),
        id: UUID.uuid4(),
        title: paging_title(index),
        raw_slug: "paging-position-#{index}",
        slug: "paging/paging-position-#{index}"
      )
    end)
  end

  defp paging_title(index) do
    "Paging Position #{String.pad_leading(Integer.to_string(index), 2, "0")}"
  end
end
