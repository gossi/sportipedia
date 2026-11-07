defmodule SportipediaWeb.Catalog.Athlete.Position.ReadPositionEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus

  describe "GET /catalog/athlete/positions/:id_or_slug (read-position)" do
    test "returns 200 with the position when found", %{conn: conn} do
      {:ok, %{id: id}} =
        Position.catalog_position(%{title: "sample-title", slug: "sample-slug-#{UUID.uuid4()}"})

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/#{id}")

      body = json_response(conn, 200)

      assert jsonapi_id(body) == id
    end

    test "returns 404 when the position does not exist", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/#{UUID.uuid4()}")

      assert json_response(conn, 404)
    end

    test "returns 200 rendering both equipment reference attributes", %{conn: conn} do
      position =
        new_position(%{
          title: "Ready Stance",
          slug: "ready-stance-#{UUID.uuid4()}",
          apparatusId: UUID.uuid4(),
          instrumentId: UUID.uuid4()
        })

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/#{position.id}")

      body = json_response(conn, 200)

      assert jsonapi_attr(body, "apparatusId") == position.apparatusId
      assert jsonapi_attr(body, "instrumentId") == position.instrumentId
    end

    # Mirrors the supported shape: a single reference produced through the
    # real command path (the case above bypasses at-most-one-equipment).
    test "renders the apparatus reference cataloged through the command path", %{conn: conn} do
      assert {:ok, apparatus} =
               Apparatus.catalog_apparatus(%{
                 title: "Balance Beam",
                 slug: "balance-beam-#{UUID.uuid4()}"
               })

      {:ok, position} =
        Position.catalog_position(%{
          title: "Handstand",
          slug: "handstand-#{UUID.uuid4()}",
          apparatusId: apparatus.id
        })

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/#{position.id}")

      body = json_response(conn, 200)

      assert jsonapi_attr(body, "apparatusId") == apparatus.id
      assert jsonapi_attr(body, "instrumentId") == nil
    end

    test "returns 404 when the position left the catalog", %{conn: conn} do
      position = new_position(%{slug: "lunge-position-#{UUID.uuid4()}"})

      Repo.delete!(position)

      conn =
        conn
        |> api_conn()
        |> get("/catalog/athlete/positions/#{position.id}")

      assert json_response(conn, 404)
    end
  end

  defp new_position(attrs) do
    defaults = %{id: UUID.uuid4(), title: "sample-title"}

    %PositionReadModel{}
    |> PositionReadModel.insert_changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end
end
