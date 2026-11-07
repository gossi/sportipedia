defmodule SportipediaWeb.Catalog.Athlete.Position.ListPositionsEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel

  describe "GET /catalog/athlete/positions (list-positions)" do
    test "returns 200 with a collection of positions", %{conn: conn} do
      {:ok, _} =
        Position.catalog_position(%{title: "sample-title", slug: "sample-slug-#{UUID.uuid4()}"})

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions")

      body = json_response(conn, 200)

      assert is_list(body["data"])
    end

    test "returns only the positions whose title matches the filter", %{conn: conn} do
      new_position(%{title: "Ready Stance", slug: "ready-stance"})
      new_position(%{title: "FRONT STANCE", slug: "front-stance"})
      new_position(%{title: "Handstand", slug: "handstand"})

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions", %{"filter" => %{"title" => "stance"}})

      body = json_response(conn, 200)

      assert Enum.sort(titles(body)) == ["FRONT STANCE", "Ready Stance"]
    end

    test "returns the positions in the order the sort asks for", %{conn: conn} do
      new_position(%{title: "Squat", slug: "squat"})
      new_position(%{title: "Burpee", slug: "burpee"})
      new_position(%{title: "Lunge", slug: "lunge"})

      ascending =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions", %{"sort" => "title"})
        |> json_response(200)

      descending =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions", %{"sort" => "-title"})
        |> json_response(200)

      assert titles(ascending) == ["Burpee", "Lunge", "Squat"]
      assert titles(descending) == ["Squat", "Lunge", "Burpee"]
    end

    test "returns the positions of the page the request asks for", %{conn: conn} do
      new_positions(25)

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions", %{
          "sort" => "title",
          "page" => %{"number" => "2", "size" => "10"}
        })

      body = json_response(conn, 200)

      assert titles(body) == Enum.map(11..20, &position_title/1)
    end
  end

  defp new_position(attrs) do
    defaults = %{
      id: UUID.uuid4(),
      title: "Position #{UUID.uuid4()}",
      slug: "position-#{UUID.uuid4()}"
    }

    %PositionReadModel{}
    |> PositionReadModel.insert_changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp new_positions(count) do
    for index <- 1..count,
        do: new_position(%{title: position_title(index), slug: "position-#{index}"})
  end

  defp position_title(index) do
    "Position " <> String.pad_leading(Integer.to_string(index), 2, "0")
  end

  defp titles(%{"data" => data}), do: Enum.map(data, & &1["attributes"]["title"])
end
