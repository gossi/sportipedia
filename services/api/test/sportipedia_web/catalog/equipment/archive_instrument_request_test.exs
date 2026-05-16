defmodule SportipediaWeb.Catalog.Equipment.ArchiveInstrumentRequestTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel

  @moduletag :integration

  describe "POST archive-instrument" do
    test "archives an instrument when authenticated" do
      id = UUID.uuid4()

      Repo.insert!(%InstrumentReadModel{
        id: id,
        title: "Unicycle",
        slug: "unicycle"
      })

      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/archive-instrument",
          Jason.encode!(jsonapi_body("instruments", %{}, id))
        )

      assert conn.status == 204
      refute Repo.get(InstrumentReadModel, id)
    end

    test "returns 403 when unauthenticated" do
      conn =
        build_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/archive-instrument",
          Jason.encode!(jsonapi_body("instruments", %{}, UUID.uuid4()))
        )

      assert json_response(conn, 403)
    end

    test "returns 204 when instrument not found (no existence check)" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> post(
          "/catalog/equipment/instruments/archive-instrument",
          Jason.encode!(jsonapi_body("instruments", %{}, UUID.uuid4()))
        )

      assert conn.status == 204
    end
  end
end
