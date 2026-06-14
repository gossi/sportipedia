defmodule SportipediaWeb.Catalog.Equipment.Instrument.EditInstrumentEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Instrument
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  alias Sportipedia.Catalog.Repo

  describe "POST /catalog/equipment/instruments/edit-instrument" do
    test "edits an existing instrument successfully", %{conn: conn} do
      # Arrange: Create an instrument first
      {:ok, %{id: id}} =
        Instrument.catalog_instrument(%{title: "Unicycle", slug: "unicycle"})

      # Act: Edit the instrument
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/edit-instrument",
          Jason.encode!(jsonapi_body("instruments", %{title: "Einrad"}, id))
        )

      # Assert
      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "type" => "instruments",
                 "attributes" => %{
                   "title" => "Einrad",
                   "slug" => "unicycle",
                   "description" => nil
                 }
               }
             } = body

      assert %InstrumentReadModel{title: "Einrad"} = Repo.get(InstrumentReadModel, id)
    end

    test "returns 403 when unauthenticated" do
      conn =
        build_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/edit-instrument",
          Jason.encode!(jsonapi_body("instruments", %{title: "Einrad"}, "some-id"))
        )

      assert json_response(conn, 403)
    end

    test "returns 404 when instrument does not exist", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/edit-instrument",
          Jason.encode!(
            jsonapi_body(
              "instruments",
              %{title: "Einrad"},
              "00000000-0000-0000-0000-000000000000"
            )
          )
        )

      assert json_response(conn, 404)
    end

    test "returns 422 when slug already exists", %{conn: conn} do
      # Arrange: Create two instruments
      {:ok, _} =
        Instrument.catalog_instrument(%{title: "Unicycle", slug: "unicycle"})

      {:ok, %{id: id2}} =
        Instrument.catalog_instrument(%{title: "Bicycle", slug: "bicycle"})

      # Act: Try to edit bicycle's slug to unicycle (which already exists)
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/edit-instrument",
          Jason.encode!(jsonapi_body("instruments", %{slug: "unicycle"}, id2))
        )

      # Assert
      assert json_response(conn, 422)
    end
  end
end
