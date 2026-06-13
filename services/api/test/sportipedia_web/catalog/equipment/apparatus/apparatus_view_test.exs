defmodule SportipediaWeb.Catalog.Equipment.Apparatus.ApparatusViewTest do
  use SportipediaWeb.ConnCase

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias SportipediaWeb.Catalog.Equipment.Apparatus.ApparatusView

  describe "type/0" do
    test "returns apparatuses" do
      assert ApparatusView.type() == "apparatuses"
    end
  end

  describe "fields/0" do
    test "returns the apparatus fields" do
      assert ApparatusView.fields() == [:title, :slug, :description]
    end
  end

  describe "path/0" do
    test "returns the apparatus path" do
      assert ApparatusView.path() == "catalog/equipment/apparatuses"
    end
  end

  describe "render show.json" do
    test "produces JSON:API single document" do
      apparatus = %ApparatusReadModel{
        id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      conn = build_conn() |> fetch_query_params()

      result =
        ApparatusView.render("show.json", %{data: apparatus, conn: conn})

      assert %{
               data: %{
                 id: "d290f1ee-6c54-4b01-90e6-d701748f0851",
                 type: "apparatuses",
                 attributes: %{
                   title: "Vaulting Table",
                   slug: "vaulting-table",
                   description: "A gymnastics vault"
                 },
                 links: %{
                   self:
                     "http://www.example.com/catalog/equipment/apparatuses/d290f1ee-6c54-4b01-90e6-d701748f0851"
                 },
                 relationships: %{}
               },
               included: [],
               links: %{
                 self:
                   "http://www.example.com/catalog/equipment/apparatuses/d290f1ee-6c54-4b01-90e6-d701748f0851"
               }
             } == result
    end
  end
end
