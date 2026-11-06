defmodule SportipediaWeb.Catalog.Athlete.Position.ListPositionsEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position
  alias SportipediaWeb.Catalog.Athlete.Position.Schemas.ListPositionsQueryParams

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
      assert Enum.any?(body["data"], &(&1["id"] != nil))
    end

    test "returns 200 to a guest", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions")

      assert body = json_response(conn, 200)
      assert body["data"] == []
    end

    test "filters by title as a case-insensitive partial match", %{conn: conn} do
      seed([{"Ready Stance", "rs"}, {"Standing Stance", "ss"}, {"Handstand", "hs"}])

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions?filter[title]=STANCE")

      titles = conn |> json_response(200) |> titles_in_document()

      assert Enum.sort(titles) == ["Ready Stance", "Standing Stance"]
    end

    test "sorts by a field, ascending or descending", %{conn: conn} do
      seed([{"Handstand", "hs"}, {"L-Sit", "ls"}, {"Mount", "mt"}])

      ascending =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions?sort=title")
        |> json_response(200)
        |> titles_in_document()

      assert ascending == ["Handstand", "L-Sit", "Mount"]

      descending =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions?sort=-title")
        |> json_response(200)
        |> titles_in_document()

      assert descending == ["Mount", "L-Sit", "Handstand"]
    end

    test "refuses to sort by a field the read does not offer", %{conn: conn} do
      # The whitelist leaves out the description and the equipment references, and
      # JSONAPI.QueryParser rejects a field it does not allow instead of quietly
      # ignoring it: a client cannot smuggle an unlisted sort in.
      assert_raise JSONAPI.Exceptions.InvalidQuery, fn ->
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions?sort=apparatusId")
      end
    end

    test "refuses to sort by a column the document does not publish", %{conn: conn} do
      # `created_at` is neither a read-model field nor an attribute of the
      # document. The parse path used to wave it through the whitelist and the
      # query builder then dropped it silently, leaving a paginated read with no
      # ORDER BY at all. A sort this read cannot honour has to be refused, not
      # ignored.
      for sort <- ["created_at", "-created_at", "updated_at", "inserted_at"] do
        assert_raise JSONAPI.Exceptions.InvalidQuery, fn ->
          conn
          |> api_conn()
          |> get("/catalog/athlete/positions?sort=#{sort}")
        end
      end
    end

    test "accepts every sort the query parameters advertise", %{conn: conn} do
      # The advertised enum and the plug's whitelist are two hand-maintained
      # lists about one behaviour. Running every advertised value through the
      # endpoint is what keeps them from drifting apart again.
      seed([{"Handstand", "hs"}])

      for sort <- ListPositionsQueryParams.schema().properties.sort.enum do
        conn =
          conn
          |> api_conn()
          |> get("/catalog/athlete/positions?sort=#{sort}")

        assert json_response(conn, 200)
      end
    end

    test "accepts every sparse fieldset the query parameters advertise", %{conn: conn} do
      # `JSONAPI.QueryParser.parse_fields/2` underscores every requested name
      # before matching it against the view's fields, so a multi-word camelCase
      # attribute like `apparatusId` becomes `:apparatus_id` and can never match
      # the view's `:apparatusId`: the parse raises instead of selecting. The
      # advertised enum therefore holds the names this read can honour.
      seed([{"Handstand", "hs"}])

      for field <- position_advertised_fields() do
        conn =
          conn
          |> api_conn()
          |> get("/catalog/athlete/positions?fields[position]=#{field}")

        assert json_response(conn, 200)
      end
    end

    test "restricts the attributes to a sparse fieldset", %{conn: conn} do
      seed([{"Handstand", "hs"}])

      body =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions?fields[position]=title")
        |> json_response(200)

      assert [%{"attributes" => attributes}] = body["data"]
      assert attributes == %{"title" => "Handstand"}
    end

    test "paginates with page number and page size", %{conn: conn} do
      for index <- 1..25 do
        Position.catalog_position(%{
          title: "Position #{index}",
          slug: "paged-#{String.pad_leading("#{index}", 2, "0")}-#{UUID.uuid4()}"
        })
      end

      first =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions?page[number]=1&page[size]=10")
        |> json_response(200)

      second =
        build_conn()
        |> api_conn()
        |> get("/catalog/athlete/positions?page[number]=2&page[size]=10")
        |> json_response(200)

      assert length(first["data"]) == 10
      assert length(second["data"]) == 10

      # Two pages of one stable order never show the same position twice.
      first_ids = Enum.map(first["data"], & &1["id"])
      second_ids = Enum.map(second["data"], & &1["id"])
      assert MapSet.disjoint?(MapSet.new(first_ids), MapSet.new(second_ids))
    end
  end

  defp seed(titles_and_slugs) do
    Enum.each(titles_and_slugs, fn {title, slug} ->
      {:ok, _} = Position.catalog_position(%{title: title, slug: "#{slug}-#{UUID.uuid4()}"})
    end)
  end

  defp titles_in_document(%{"data" => data}), do: Enum.map(data, & &1["attributes"]["title"])

  defp position_advertised_fields do
    ListPositionsQueryParams.schema().properties.fields.properties.position.enum
  end
end
