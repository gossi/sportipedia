defmodule SportipediaWeb.Catalog.Athlete.Position.ArchivePositionEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel

  @admin %{id: UUID.uuid4(), role: "admin"}

  describe "POST /catalog/athlete/positions/archive-position" do
    test "archive-position returns 204 for an archived position", %{conn: conn} do
      {:ok, %{id: id}} =
        Position.catalog_position(%{title: "sample-title", slug: "sample-slug-#{UUID.uuid4()}"})

      conn =
        conn
        |> authenticate_conn(@admin)
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/archive-position",
          Jason.encode!(jsonapi_body("position", %{}, id))
        )

      assert conn.status == 204
      assert conn.resp_body == ""

      # Archived is deleted: the read model no longer holds the row, and the
      # event stays in the store as the audit trail. Nothing in the API offers an
      # unarchive.
      assert Repo.get(PositionReadModel, id) == nil
      assert {:error, :not_found} = Position.read_position(id)
    end

    test "returns 404 for an unknown id", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn(@admin)
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/archive-position",
          Jason.encode!(jsonapi_body("position", %{}, UUID.uuid4()))
        )

      assert json_response(conn, 404)
    end

    test "returns 404 for a position that is already archived", %{conn: conn} do
      {:ok, %{id: id}} =
        Position.catalog_position(%{title: "sample-title", slug: "sample-slug-#{UUID.uuid4()}"})

      first =
        build_conn()
        |> authenticate_conn(@admin)
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/archive-position",
          Jason.encode!(jsonapi_body("position", %{}, id))
        )

      assert first.status == 204

      conn =
        conn
        |> authenticate_conn(@admin)
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/archive-position",
          Jason.encode!(jsonapi_body("position", %{}, id))
        )

      assert json_response(conn, 404)
    end

    test "returns 422 for a request without an id", %{conn: conn} do
      # An address the command cannot hold must not reach the existence check's
      # lookup: `Repo.get/2` raises on nil and on a blank string, and the raise
      # answered 500 before `presence` could say 422.
      for body <- [jsonapi_body("position", %{}), jsonapi_body("position", %{}, "")] do
        conn =
          conn
          |> authenticate_conn(@admin)
          |> api_conn()
          |> post("/catalog/athlete/positions/archive-position", Jason.encode!(body))

        assert %{"errors" => [error]} = json_response(conn, 422)
        assert error["status"] == "422"
        assert error["detail"] == "must be present"
        assert error["title"] == "id"
      end
    end

    test "returns 404 for an id that is not an id", %{conn: conn} do
      # A string that cannot denote a position addresses nothing: the same answer
      # as for an unknown one, and still not a 500.
      conn =
        conn
        |> authenticate_conn(@admin)
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/archive-position",
          Jason.encode!(jsonapi_body("position", %{}, "not-a-uuid"))
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

    # archive-position's actor is admin, so an authenticated user who is not an
    # admin is denied — the same answer whether the id is known or not, because
    # the Bodyguard plug runs before the command is dispatched.
    test "returns 403 for an authenticated user who is not an admin", %{conn: conn} do
      {:ok, %{id: id}} =
        Position.catalog_position(%{title: "sample-title", slug: "sample-slug-#{UUID.uuid4()}"})

      conn =
        conn
        |> authenticate_conn(%{id: UUID.uuid4(), role: "user"})
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/archive-position",
          Jason.encode!(jsonapi_body("position", %{}, id))
        )

      assert json_response(conn, 403)

      assert Repo.get(PositionReadModel, id) != nil
    end
  end
end
