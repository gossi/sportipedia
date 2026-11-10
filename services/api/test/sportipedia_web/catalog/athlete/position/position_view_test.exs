defmodule SportipediaWeb.Catalog.Athlete.Position.PositionViewTest do
  use SportipediaWeb.ConnCase
  alias Sportipedia.Catalog.Athlete.Position.PositionReadModel
  alias SportipediaWeb.Catalog.Athlete.Position.PositionView

  describe "type/0" do
    test "returns position" do
      assert PositionView.type() == "position"
    end
  end

  describe "fields/0" do
    test "returns the position fields" do
      assert PositionView.fields() == [
               :title,
               :slug,
               :apparatusId,
               :description,
               :instrumentId
             ]
    end
  end

  describe "path/0" do
    test "returns the position path" do
      assert PositionView.path() == "catalog/athlete/positions"
    end
  end

  describe "render show.json" do
    test "produces JSON:API single document" do
      position = %PositionReadModel{
        id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
        title: "Riding",
        slug: "riding",
        lookup_slug: "unicycle/riding",
        apparatusId: UUID.uuid4(),
        description: "Riding on a unicycle",
        instrumentId: UUID.uuid5(:dns, "equipment:instrument:unicycle")
      }

      conn = build_conn() |> fetch_query_params()

      result = PositionView.render("show.json", %{data: position, conn: conn})

      assert %{data: %{id: "d290f1ee-6c54-4b01-90e6-d701748f0851", type: "position"}} =
               result
    end

    test "publishes the canonical lookup path as the slug attribute" do
      position = %PositionReadModel{
        id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
        title: "Long Hang",
        slug: "long-hang",
        lookup_slug: "horizontal-bar/long-hang",
        apparatusId: UUID.uuid5(:dns, "equipment:apparatus:horizontal-bar"),
        description: "Athlete has their arms straight while hanging on the bar"
      }

      conn = build_conn() |> fetch_query_params()

      result = PositionView.render("show.json", %{data: position, conn: conn})

      assert result.data.attributes.slug == "horizontal-bar/long-hang"
      refute Map.has_key?(result.data.attributes, :lookup_slug)
    end
  end
end
