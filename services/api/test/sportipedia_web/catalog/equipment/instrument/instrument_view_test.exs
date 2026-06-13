defmodule SportipediaWeb.Catalog.Equipment.Instrument.InstrumentViewTest do
  use SportipediaWeb.ConnCase

  alias SportipediaWeb.Catalog.Equipment.Instrument.InstrumentView
  alias Sportipedia.Catalog.Equipment.Instrument.InstrumentReadModel

  import SportipediaWeb.RequestHelpers

  describe "View" do
    @describetag :unit

    test "type/0 returns instruments" do
      assert InstrumentView.type() == "instruments"
    end

    test "fields/0 lists the attributes" do
      assert InstrumentView.fields() == [:title, :slug, :description]
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
end
