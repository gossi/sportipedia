defmodule SportipediaWeb.Catalog.Equipment.Instrument.CatalogInstrumentEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  alias Sportipedia.Catalog.Repo

  describe "POST /catalog/equipment/instruments/catalog-instrument" do
    test "catalog-instrument returns 201 with the cataloged instrument", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/catalog-instrument",
          Jason.encode!(
            jsonapi_body("instruments", %{
              title: "Unicycle",
              slug: "unicycle",
              description: "A single-wheeled vehicle"
            })
          )
        )

      body = json_response(conn, 201)

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "instruments",
                 "attributes" => %{
                   "title" => "Unicycle",
                   "slug" => "unicycle",
                   "description" => "A single-wheeled vehicle"
                 }
               }
             } = body

      assert is_binary(id)
      assert Repo.get(InstrumentReadModel, id)
    end

    test "catalog-instrument works without optional description", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/catalog-instrument",
          Jason.encode!(
            jsonapi_body("instruments", %{
              title: "Pogo Stick",
              slug: "pogo-stick"
            })
          )
        )

      body = json_response(conn, 201)

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "instruments",
                 "attributes" => %{
                   "title" => "Pogo Stick",
                   "slug" => "pogo-stick"
                 }
               }
             } = body

      assert Repo.get(InstrumentReadModel, id)
    end

    test "returns 403 when unauthenticated" do
      conn =
        build_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/catalog-instrument",
          Jason.encode!(
            jsonapi_body("instruments", %{
              title: "Unicycle",
              slug: "unicycle"
            })
          )
        )

      assert json_response(conn, 403)
    end

    test "returns 422 when title is missing", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/catalog-instrument",
          Jason.encode!(
            jsonapi_body("instruments", %{
              slug: "unicycle"
            })
          )
        )

      assert json_response(conn, 422)
    end

    test "returns 422 when slug is missing", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/catalog-instrument",
          Jason.encode!(
            jsonapi_body("instruments", %{
              title: "Unicycle"
            })
          )
        )

      assert json_response(conn, 422)
    end

    test "returns 422 when slug already exists", %{conn: conn} do
      # First, catalog an instrument
      conn
      |> authenticate_conn()
      |> api_conn()
      |> post(
        "/catalog/equipment/instruments/catalog-instrument",
        Jason.encode!(
          jsonapi_body("instruments", %{
            title: "Unicycle",
            slug: "unicycle",
            description: "A single-wheeled vehicle"
          })
        )
      )

      # Then try to catalog another with the same slug
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/catalog-instrument",
          Jason.encode!(
            jsonapi_body("instruments", %{
              title: "Another Unicycle",
              slug: "unicycle"
            })
          )
        )

      assert json_response(conn, 422)
    end
  end
end
