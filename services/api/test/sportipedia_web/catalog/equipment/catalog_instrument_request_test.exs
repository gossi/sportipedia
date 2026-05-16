defmodule SportipediaWeb.Catalog.Equipment.CatalogInstrumentRequestTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel

  @moduletag :integration

  describe "POST catalog-instrument" do
    test "creates instrument when authenticated" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/catalog-instrument",
          Jason.encode!(
            jsonapi_body("instruments", %{
              title: "Unicycle",
              slug: "unicycle",
              description: "Best vehicle in the world"
            })
          )
        )

      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "instruments",
                 "attributes" => %{
                   "title" => "Unicycle",
                   "slug" => "unicycle",
                   "description" => "Best vehicle in the world"
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
          Jason.encode!(jsonapi_body("instruments", %{title: "Unicycle", slug: "unicycle"}))
        )

      assert json_response(conn, 403)
    end

    test "returns 422 when title is missing" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/catalog-instrument",
          Jason.encode!(jsonapi_body("instruments", %{slug: "unicycle"}))
        )

      assert json_response(conn, 422)
    end

    test "returns 422 when slug is missing" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/catalog-instrument",
          Jason.encode!(jsonapi_body("instruments", %{title: "Unicycle"}))
        )

      assert json_response(conn, 422)
    end

    test "returns 422 when slug already exists" do
      Repo.insert!(%InstrumentReadModel{
        id: UUID.uuid4(),
        title: "Existing",
        slug: "unicycle"
      })

      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/catalog-instrument",
          Jason.encode!(jsonapi_body("instruments", %{title: "Unicycle", slug: "unicycle"}))
        )

      assert json_response(conn, 422)
    end
  end
end
