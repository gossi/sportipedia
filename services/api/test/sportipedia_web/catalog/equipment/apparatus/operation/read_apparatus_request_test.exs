defmodule SportipediaWeb.Catalog.Equipment.Apparatus.ReadApparatusRequestTest do
  use SportipediaWeb.ConnCase

  import SportipediaWeb.RequestHelpers

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusProjector
  alias Sportipedia.Catalog.Equipment.Apparatus.Event.ApparatusCataloged

  @moduletag :integration

  describe "GET read-apparatus" do
    setup do
      apparatus_id = UUID.uuid4()

      event = %ApparatusCataloged{
        id: apparatus_id,
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      metadata = %{
        handler_name: "equipment.apparatus_projection",
        event_number: 1,
        event_id: UUID.uuid4(),
        stream_id: "equipment/apparatus-#{apparatus_id}",
        stream_version: 1,
        correlation_id: nil,
        causation_id: nil,
        created_at: DateTime.utc_now(),
        application: Sportipedia.Catalog,
        state: nil
      }

      assert :ok = ApparatusProjector.handle(event, metadata)

      %{apparatus_id: apparatus_id}
    end

    test "returns 200 and apparatus data when found by id", %{apparatus_id: apparatus_id} do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses/#{apparatus_id}")

      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => ^apparatus_id,
                 "type" => "apparatuses",
                 "attributes" => %{
                   "title" => "Vaulting Table",
                   "slug" => "vaulting-table",
                   "description" => "A gymnastics vault"
                 }
               }
             } = body
    end

    test "returns 404 when apparatus not found" do
      conn =
        build_conn()
        |> authenticate_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses/non-existent-id")

      json_response(conn, 404)
    end

    test "returns 200 for unauthenticated (guest) reads", %{apparatus_id: apparatus_id} do
      conn =
        build_conn()
        |> api_conn()
        |> get("/catalog/equipment/apparatuses/#{apparatus_id}")

      body = json_response(conn, 200)

      assert %{
               "data" => %{
                 "id" => ^apparatus_id,
                 "type" => "apparatuses",
                 "attributes" => %{
                   "title" => "Vaulting Table",
                   "slug" => "vaulting-table"
                 }
               }
             } = body
    end
  end
end
