defmodule SportipediaWeb.Catalog.Athlete.Position.CatalogPositionEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Athlete.Position
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias Sportipedia.Catalog.Equipment.Apparatus
  alias Sportipedia.Catalog.Equipment.Instrument

  describe "POST /catalog/athlete/positions/catalog-position" do
    test "catalog-position returns 200 with the position", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{title: "sample-title", slug: "sample-slug-#{UUID.uuid4()}"})
          )
        )

      body = json_response(conn, 200)

      assert jsonapi_type(body) == "position"
      assert jsonapi_attr(body, "title") == "sample-title"
      assert jsonapi_attr(body, "apparatusId") == nil
      assert jsonapi_attr(body, "instrumentId") == nil
    end

    test "catalog-position returns 200 with the equipment reference", %{conn: conn} do
      {:ok, apparatus} = Apparatus.catalog_apparatus(%{title: "Vault", slug: "vault"})

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{
              title: "Vault Approach",
              slug: "vault-approach-#{UUID.uuid4()}",
              apparatusId: apparatus.id
            })
          )
        )

      body = json_response(conn, 200)

      assert jsonapi_attr(body, "apparatusId") == apparatus.id
      assert jsonapi_attr(body, "instrumentId") == nil
    end

    test "returns 422 for a slug another position already has", %{conn: conn} do
      slug = "guard-position-#{UUID.uuid4()}"
      {:ok, _existing} = Position.catalog_position(%{title: "Guard", slug: slug})

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(jsonapi_body("position", %{title: "Another Guard", slug: slug}))
        )

      assert %{"errors" => [error]} = json_response(conn, 422)

      assert error["status"] == "422"
      assert error["detail"] == "slug_exists"
      assert error["source"] == %{"pointer" => "/data/attributes/slug"}
      assert Repo.aggregate(PositionReadModel, :count) == 1
    end

    test "returns 422 when both an apparatus and an instrument are referenced", %{conn: conn} do
      {:ok, apparatus} = Apparatus.catalog_apparatus(%{title: "Rings", slug: "rings"})
      {:ok, instrument} = Instrument.catalog_instrument(%{title: "Drum", slug: "drum"})

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{
              title: "Impossible",
              slug: "impossible-#{UUID.uuid4()}",
              apparatusId: apparatus.id,
              instrumentId: instrument.id
            })
          )
        )

      assert %{"errors" => [error]} = json_response(conn, 422)
      assert error["status"] == "422"
      assert error["detail"] == "at_most_one_equipment"
      assert error["source"] == %{"pointer" => "/data/attributes/apparatusId"}
      assert Repo.aggregate(PositionReadModel, :count) == 0
    end

    test "returns 422 — not 404 — for an equipment reference that is not in the catalog", %{
      conn: conn
    } do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{
              title: "Phantom",
              slug: "phantom-#{UUID.uuid4()}",
              apparatusId: UUID.uuid4()
            })
          )
        )

      # A missing apparatus is a fixable attribute of the request, so the command
      # must not collapse into a whole-resource 404.
      assert %{"errors" => [error]} = json_response(conn, 422)
      assert error["status"] == "422"
      assert error["detail"] == "equipment_not_found"
      assert error["source"] == %{"pointer" => "/data/attributes/apparatusId"}
      assert Repo.aggregate(PositionReadModel, :count) == 0
    end

    test "returns 422 for an instrument reference that is not in the catalog", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{
              title: "Phantom Shuttlecock",
              slug: "phantom-shuttlecock-#{UUID.uuid4()}",
              instrumentId: UUID.uuid4()
            })
          )
        )

      # One rule covers both equipment kinds, and each kind names the field the
      # client can fix.
      assert %{"errors" => [error]} = json_response(conn, 422)
      assert error["status"] == "422"
      assert error["detail"] == "equipment_not_found"
      assert error["source"] == %{"pointer" => "/data/attributes/instrumentId"}
      assert Repo.aggregate(PositionReadModel, :count) == 0
    end

    test "returns 403 when unauthenticated", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(jsonapi_body("position", %{}))
        )

      assert json_response(conn, 403)
    end
  end
end
