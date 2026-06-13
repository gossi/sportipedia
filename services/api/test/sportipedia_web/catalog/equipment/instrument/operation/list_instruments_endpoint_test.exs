defmodule SportipediaWeb.Catalog.Equipment.Instrument.ListInstrumentsEndpointTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Instrument

  describe "GET /catalog/equipment/instruments (list-instruments)" do
    test "returns 200 with an empty collection when no instruments exist", %{conn: conn} do
      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/instruments")

      body = json_response(conn, 200)

      assert %{"data" => data} = body
      assert is_list(data)
      assert data == []
    end

    test "returns 200 with a collection of instruments", %{conn: conn} do
      {:ok, _i1} =
        Instrument.catalog_instrument(%{title: "Unicycle", slug: "unicycle", description: "One wheel"})

      {:ok, _i2} =
        Instrument.catalog_instrument(%{title: "Skateboard", slug: "skateboard", description: nil})

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/instruments")

      body = json_response(conn, 200)

      assert %{"data" => data} = body
      assert is_list(data)
      assert length(data) == 2

      titles = Enum.map(data, fn item -> item["attributes"]["title"] end)
      assert "Unicycle" in titles
      assert "Skateboard" in titles
    end

    test "returns 200 for unauthenticated (guest) requests", %{conn: conn} do
      {:ok, _i1} =
        Instrument.catalog_instrument(%{title: "Trampoline", slug: "trampoline", description: nil})

      conn =
        conn
        |> api_conn()
        |> get("/catalog/equipment/instruments")

      body = json_response(conn, 200)

      assert %{"data" => data} = body
      assert is_list(data)
      assert length(data) == 1
    end

    test "filters instruments by title (case-insensitive partial match)", %{conn: conn} do
      {:ok, _i1} =
        Instrument.catalog_instrument(%{title: "Vaulting Table", slug: "vaulting-table", description: nil})

      {:ok, _i2} =
        Instrument.catalog_instrument(%{title: "Pommel Horse", slug: "pommel-horse", description: nil})

      {:ok, _i3} =
        Instrument.catalog_instrument(%{title: "Still Rings", slug: "still-rings", description: nil})

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/instruments?filter[title]=vault")

      body = json_response(conn, 200)

      assert %{"data" => data} = body
      assert is_list(data)
      assert length(data) == 1
      assert hd(data)["attributes"]["title"] == "Vaulting Table"
    end

    test "sorts instruments by title ascending", %{conn: conn} do
      {:ok, _i1} =
        Instrument.catalog_instrument(%{title: "Skateboard", slug: "skateboard", description: nil})

      {:ok, _i2} =
        Instrument.catalog_instrument(%{title: "Unicycle", slug: "unicycle", description: nil})

      {:ok, _i3} =
        Instrument.catalog_instrument(%{title: "Trampoline", slug: "trampoline", description: nil})

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/instruments?sort=title")

      body = json_response(conn, 200)

      assert %{"data" => data} = body
      titles = Enum.map(data, fn item -> item["attributes"]["title"] end)
      assert titles == ["Skateboard", "Trampoline", "Unicycle"]
    end

    test "sorts instruments by title descending", %{conn: conn} do
      {:ok, _i1} =
        Instrument.catalog_instrument(%{title: "Skateboard", slug: "skateboard", description: nil})

      {:ok, _i2} =
        Instrument.catalog_instrument(%{title: "Unicycle", slug: "unicycle", description: nil})

      {:ok, _i3} =
        Instrument.catalog_instrument(%{title: "Trampoline", slug: "trampoline", description: nil})

      conn =
        conn
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/instruments?sort=-title")

      body = json_response(conn, 200)

      assert %{"data" => data} = body
      titles = Enum.map(data, fn item -> item["attributes"]["title"] end)
      assert titles == ["Unicycle", "Trampoline", "Skateboard"]
    end
  end
end
