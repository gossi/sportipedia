defmodule SportipediaWeb.Catalog.Athlete.Position.ArchivePositionEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.TestSupport.Catalog.Athlete
  alias Sportipedia.TestSupport.Catalog.Athlete.PositionFixtures

  @moduletag :integration

  describe "POST /catalog/athlete/positions/archive-position" do
    test "archive-position returns 204 for a cataloged position", %{conn: conn} do
      {:ok, seeded} = Position.catalog_position(%{title: "Riding", slug: "riding-204"})

      conn =
        conn
        |> authenticate_conn(%{id: UUID.uuid4(), role: "admin"})
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/archive-position",
          Jason.encode!(jsonapi_body("position", %{}, seeded.id))
        )

      assert conn.status == 204
      assert conn.resp_body == ""
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn(%{id: UUID.uuid4(), role: "admin"})
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/archive-position",
          Jason.encode!(jsonapi_body("position", %{}, UUID.uuid4()))
        )

      assert json_response(conn, 404)
    end

    test "returns 403 when unauthenticated", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/archive-position",
          Jason.encode!(jsonapi_body("position", %{}))
        )

      assert json_response(conn, 403)
    end

    test "returns 403 for an authenticated user who is not an admin", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn(%{id: UUID.uuid4(), role: "user"})
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/archive-position",
          Jason.encode!(jsonapi_body("position", %{}, UUID.uuid4()))
        )

      assert json_response(conn, 403)
    end

    test "returns 404 when the position is archived again — there is no archived state to re-archive",
         %{conn: conn} do
      {:ok, seeded} =
        Position.catalog_position(%{title: "Straight-arm support", slug: "straight-arm-support"})

      body = Jason.encode!(jsonapi_body("position", %{}, seeded.id))

      conn =
        conn
        |> authenticate_conn(%{id: UUID.uuid4(), role: "admin"})
        |> api_conn()
        |> post("/catalog/athlete/positions/archive-position", body)

      assert conn.status == 204
      assert conn.resp_body == ""

      retried =
        build_conn()
        |> authenticate_conn(%{id: UUID.uuid4(), role: "admin"})
        |> api_conn()
        |> post("/catalog/athlete/positions/archive-position", body)

      assert json_response(retried, 404)
    end
  end

  describe "GET /catalog/athlete/positions/:id_or_slug after archive-position" do
    test "read-position answers 404 for a guest after the position is archived", %{conn: conn} do
      {:ok, seeded} = Position.catalog_position(%{title: "Long Hang", slug: "long-hang"})

      conn =
        conn
        |> authenticate_conn(%{id: UUID.uuid4(), role: "admin"})
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/archive-position",
          Jason.encode!(jsonapi_body("position", %{}, seeded.id))
        )

      assert conn.status == 204

      guest_conn = build_conn() |> get("/catalog/athlete/positions/#{seeded.id}")

      assert json_response(guest_conn, 404)
    end

    test "the archived position is absent from the position list", %{conn: conn} do
      {:ok, archived} =
        Position.catalog_position(%{title: "Seat in-front", slug: "seat-in-front"})

      {:ok, survivor} = Athlete.new_position(PositionFixtures.unicycle_riding())

      conn =
        conn
        |> authenticate_conn(%{id: UUID.uuid4(), role: "admin"})
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/archive-position",
          Jason.encode!(jsonapi_body("position", %{}, archived.id))
        )

      assert conn.status == 204

      list_conn = build_conn() |> get("/catalog/athlete/positions")

      collection = json_response(list_conn, 200)

      ids = Enum.map(collection["data"], & &1["id"])

      refute archived.id in ids
      assert survivor.id in ids
    end
  end
end
