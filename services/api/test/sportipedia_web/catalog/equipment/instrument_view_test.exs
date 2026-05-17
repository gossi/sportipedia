defmodule SportipediaWeb.Catalog.Equipment.InstrumentViewTest do
  use SportipediaWeb.ConnCase

  alias SportipediaWeb.Catalog.Equipment.InstrumentView
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel

  import SportipediaWeb.RequestHelpers

  describe "View" do
    @describetag :unit

    test "type/0 returns instruments" do
      assert InstrumentView.type() == "instruments"
    end

    test "fields/0 lists the attributes" do
      assert InstrumentView.fields() == [:title, :description, :slug]
    end

    test "path/0 returns the API path" do
      assert InstrumentView.path() == "catalog/equipment/instruments"
    end

    test "render show.json produces JSON:API single document" do
      instrument = %InstrumentReadModel{
        id: "abc-123",
        title: "Unicycle",
        slug: "unicycle",
        description: "Best vehicle in the world"
      }

      conn = build_conn() |> fetch_query_params()
      result = InstrumentView.render("show.json", %{data: instrument, conn: conn})

      assert %{
               data: %{
                 id: "abc-123",
                 type: "instruments",
                 attributes: %{
                   title: "Unicycle",
                   slug: "unicycle",
                   description: "Best vehicle in the world"
                 }
               }
             } = result
    end

    test "render index.json produces JSON:API collection" do
      instrument = %InstrumentReadModel{
        id: "abc-123",
        title: "Unicycle",
        slug: "unicycle",
        description: "Best vehicle in the world"
      }

      conn = build_conn() |> fetch_query_params()
      result = InstrumentView.render("index.json", %{data: [instrument], conn: conn})

      assert %{data: [item]} = result
      assert item.id == "abc-123"
      assert item.type == "instruments"
      assert item.attributes.title == "Unicycle"
    end
  end

  describe "GET /:id read-instrument" do
    @describetag :integration

    test "returns instrument when found" do
      id = UUID.uuid4()

      Repo.insert!(%InstrumentReadModel{
        id: id,
        title: "Unicycle",
        slug: "unicycle"
      })

      conn =
        build_conn()
        |> get("/catalog/equipment/instruments/#{id}")

      body = json_response(conn, 200)

      assert jsonapi_id(body) == id
      assert jsonapi_attr(body, "title") == "Unicycle"
    end

    test "returns 404 when not found" do
      conn =
        build_conn()
        |> get("/catalog/equipment/instruments/#{UUID.uuid4()}")

      assert json_response(conn, 404)
    end
  end

  describe "GET / list-instruments" do
    @describetag :integration

    test "returns empty list" do
      conn =
        build_conn()
        |> get("/catalog/equipment/instruments")

      body = json_response(conn, 200)

      assert body["data"] == []
    end

    test "returns all instruments" do
      Repo.insert!(%InstrumentReadModel{id: UUID.uuid4(), title: "A", slug: "a"})
      Repo.insert!(%InstrumentReadModel{id: UUID.uuid4(), title: "B", slug: "b"})

      conn =
        build_conn()
        |> get("/catalog/equipment/instruments")

      body = json_response(conn, 200)

      assert length(body["data"]) == 2
    end

    test "filters by title" do
      Repo.insert!(%InstrumentReadModel{id: UUID.uuid4(), title: "Matching", slug: "matching"})
      Repo.insert!(%InstrumentReadModel{id: UUID.uuid4(), title: "Other", slug: "other"})

      conn =
        build_conn()
        |> get("/catalog/equipment/instruments?filter[title]=Matching")

      body = json_response(conn, 200)

      assert length(body["data"]) == 1
      assert body["data"] |> List.first() |> get_in(["attributes", "title"]) == "Matching"
    end
  end
end
