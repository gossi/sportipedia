defmodule SportipediaWeb.Catalog.Athlete.Position.EditPositionEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.TestSupport.Catalog.Equipment
  alias Sportipedia.TestSupport.Catalog.Equipment.ApparatusFixtures
  alias Sportipedia.TestSupport.Catalog.Equipment.InstrumentFixtures

  @moduletag :integration

  describe "POST /catalog/athlete/positions/edit-position" do
    test "edit-position returns 200 with the position", %{conn: conn} do
      catalog_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(jsonapi_body("position", %{title: "Riding", slug: "riding"}))
        )

      catalog_body = json_response(catalog_conn, 200)
      id = jsonapi_id(catalog_body)

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{}, id))
        )

      body = json_response(conn, 200)

      assert jsonapi_id(body) == id
    end

    test "returns 200 with the renamed position at its canonical path", %{conn: conn} do
      {:ok, unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())

      catalog_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{
              title: "Riding",
              slug: "riding",
              instrumentId: unicycle.id
            })
          )
        )

      id = catalog_conn |> json_response(200) |> jsonapi_id()

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{slug: "balancing"}, id))
        )

      body = json_response(conn, 200)

      # The published `slug` is the canonical lookup path, and it tracks the raw
      # slug the patch supplied — the boundary holds that slug canonical, and it
      # stays namespaced by the equipment the position did not move away from.
      assert jsonapi_attr(body, "slug") == "unicycle/balancing"
      assert jsonapi_attr(body, "instrumentId") == unicycle.id
    end

    test "returns 422 when the edit carries both equipment references", %{conn: conn} do
      {:ok, unicycle} = Equipment.new_instrument(InstrumentFixtures.unicycle())
      {:ok, parallel_bars} = Equipment.new_apparatus(ApparatusFixtures.parallel_bars())

      catalog_conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/catalog-position",
          Jason.encode!(
            jsonapi_body("position", %{
              title: "Riding",
              slug: "riding",
              instrumentId: unicycle.id
            })
          )
        )

      id = catalog_conn |> json_response(200) |> jsonapi_id()

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(
            jsonapi_body(
              "position",
              %{
                apparatusId: parallel_bars.id,
                instrumentId: unicycle.id
              },
              id
            )
          )
        )

      assert %{"errors" => errors} = json_response(conn, 422)

      answered = Map.new(errors, fn error -> {error["source"]["pointer"], error["detail"]} end)

      assert answered["/data/attributes/apparatusId"] == "too_many_equipment"
      assert answered["/data/attributes/instrumentId"] == "too_many_equipment"
    end

    test "returns 403 when unauthenticated", %{conn: conn} do
      conn =
        conn
        |> api_conn()
        |> post(
          "/catalog/athlete/positions/edit-position",
          Jason.encode!(jsonapi_body("position", %{}))
        )

      assert json_response(conn, 403)
    end
  end
end
