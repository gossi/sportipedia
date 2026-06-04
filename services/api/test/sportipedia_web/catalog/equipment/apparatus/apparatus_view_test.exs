defmodule SportipediaWeb.Catalog.Equipment.ApparatusViewTest do
  use SportipediaWeb.ConnCase

  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel
  alias SportipediaWeb.Catalog.Equipment.ApparatusView

  describe "View" do
    test "type/0 returns apparatuses" do
      assert ApparatusView.type() == "apparatuses"
    end

    test "path/0 returns the correct path" do
      assert ApparatusView.path() == "catalog/equipment/apparatuses"
    end

    test "fields/0 returns the correct fields" do
      assert ApparatusView.fields() == [:id, :title, :slug, :description]
    end

    test "render show.json produces JSON:API single document" do
      apparatus = %ApparatusReadModel{
        id: "a1b2c3d4",
        title: "Vaulting Table",
        slug: "vaulting-table",
        description: "A gymnastics vault"
      }

      conn = build_conn() |> fetch_query_params()

      result = ApparatusView.render("show.json", %{data: apparatus, conn: conn})

      assert %{
               data: %{
                 id: "a1b2c3d4",
                 type: "apparatuses",
                 attributes: %{
                   title: "Vaulting Table",
                   slug: "vaulting-table",
                   description: "A gymnastics vault"
                 }
               }
             } = result
    end
  end
end
