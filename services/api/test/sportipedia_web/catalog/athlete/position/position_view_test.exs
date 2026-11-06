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
      # Exactly the attributes the domain model's read-model schema declares:
      # an attribute the model does not state must not be published.
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
        title: "sample-title",
        slug: "sample-slug",
        apparatusId: UUID.uuid4(),
        description: "sample-description",
        instrumentId: UUID.uuid4()
      }

      conn = build_conn() |> fetch_query_params()

      result = PositionView.render("show.json", %{data: position, conn: conn})

      assert %{data: %{id: "d290f1ee-6c54-4b01-90e6-d701748f0851", type: "position"}} =
               result
    end
  end
end
