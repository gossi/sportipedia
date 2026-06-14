defmodule SportipediaWeb.Catalog.Equipment.Instrument.ReadInstrumentEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Instrument
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  alias SportipediaWeb.Catalog.Equipment.Instrument.InstrumentView

  describe "GET /catalog/equipment/instruments/:id (read-instrument by id)" do
    test "returns 200 with the instrument when found", %{conn: conn} do
      # Arrange: Catalog an instrument via public API
      {:ok, instrument} =
        Instrument.catalog_instrument(%{title: "Vaulting Table", slug: "vaulting-table"})

      # Act: Read the instrument by id
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/instruments/#{instrument.id}")

      # Assert: 200 with the instrument
      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "instruments",
                 "attributes" => %{
                   "title" => "Vaulting Table",
                   "slug" => "vaulting-table"
                 }
               }
             } = body

      assert id == instrument.id
    end

    test "returns 404 when instrument not found", %{conn: conn} do
      # Act: Read a non-existing instrument
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/instruments/#{UUID.uuid4()}")

      # Assert: 404
      assert json_response(conn, 404)
    end

    test "returns 200 for unauthenticated (guest) request", %{conn: conn} do
      # Arrange: Catalog an instrument
      {:ok, instrument} =
        Instrument.catalog_instrument(%{title: "Pommel Horse", slug: "pommel-horse"})

      # Act: Read without authentication
      conn =
        conn
        |> api_conn()
        |> get("/catalog/equipment/instruments/#{instrument.id}")

      # Assert: 200 (guest allowed)
      body = json_response(conn, 200)
      assert jsonapi_id(body) == instrument.id
    end
  end

  describe "GET /catalog/equipment/instruments?filter[slug]=... (read-instrument by slug)" do
    test "returns 200 with the instrument when slug matches", %{conn: conn} do
      # Arrange: Catalog an instrument
      {:ok, _instrument} =
        Instrument.catalog_instrument(%{title: "Still Rings", slug: "still-rings"})

      # Act: Read by slug
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/instruments?filter[slug]=still-rings")

      # Assert: 200 with the instrument
      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => id,
                 "type" => "instruments",
                 "attributes" => %{
                   "title" => "Still Rings",
                   "slug" => "still-rings"
                 }
               }
             } = body

      assert id == _instrument.id
    end

    test "returns 404 when slug does not match any instrument", %{conn: conn} do
      # Act: Read by non-existing slug
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/instruments?filter[slug]=non-existing-slug")

      # Assert: 404
      assert json_response(conn, 404)
    end
  end
end
