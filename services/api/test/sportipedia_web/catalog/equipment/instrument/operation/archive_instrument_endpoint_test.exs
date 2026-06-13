defmodule SportipediaWeb.Catalog.Equipment.Instrument.ArchiveInstrumentEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Instrument

  describe "POST /catalog/equipment/instruments/archive-instrument" do
    test "archives an existing instrument successfully", %{conn: conn} do
      # Arrange: Create an instrument first
      {:ok, %{id: id}} =
        Instrument.catalog_instrument(%{title: "Skateboard", slug: "skateboard"})

      # Act: Archive the instrument
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> post("/catalog/equipment/instruments/archive-instrument",
          Jason.encode!(jsonapi_body("instruments", %{}, id))
        )

      # Assert
      assert response(conn, 204)
    end

    test "returns 403 when unauthenticated" do
      conn =
        build_conn()
        |> api_conn()
        |> post("/catalog/equipment/instruments/archive-instrument",
          Jason.encode!(jsonapi_body("instruments", %{}, "some-id"))
        )

      assert json_response(conn, 403)
    end
  end
end
