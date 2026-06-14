defmodule SportipediaWeb.Catalog.Equipment.Instrument.ReadInstrumentEndpointTest do
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Instrument

  describe "GET /catalog/equipment/instruments/:id (read-instrument by id)" do
    test "returns 200 with the instrument when found by id", %{conn: conn} do
      # Arrange: Catalog an instrument via public API
      {:ok, %InstrumentReadModel{id: id}} =
        Instrument.catalog_instrument(%{title: "Unicycle", slug: "unicycle"})

      # Act: Read the instrument by id
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/instruments/#{id}")

      # Assert: 200 with the instrument
      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "type" => "instruments",
                 "attributes" => %{
                   "title" => "Unicycle",
                   "slug" => "unicycle"
                 }
               }
             } = body
    end

    test "returns 200 with instrument when found by slug", %{conn: conn} do
      # Arrange: Catalog an instrument via public API
      {:ok, %InstrumentReadModel{id: id}} =
        Instrument.catalog_instrument(%{title: "Unicycle", slug: "unicycle"})

      # Act: Read the instrument by id
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/instruments/unicycle")

      # Assert: 200 with the instrument
      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => ^id,
                 "type" => "instruments",
                 "attributes" => %{
                   "title" => "Unicycle",
                   "slug" => "unicycle"
                 }
               }
             } = body
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
      {:ok, %InstrumentReadModel{id: id}} =
        Instrument.catalog_instrument(%{title: "Skateboard", slug: "skateboard"})

      # Act: Read without authentication
      conn =
        conn
        |> api_conn()
        |> get("/catalog/equipment/instruments/#{id}")

      # Assert: 200 (guest allowed)
      body = json_response(conn, 200)
      assert jsonapi_id(body) == id
    end
  end
end
