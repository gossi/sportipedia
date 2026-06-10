defmodule SportipediaWeb.Catalog.Equipment.ApparatusViewTest do
  use SportipediaWeb.ConnCase

  alias SportipediaWeb.Catalog.Equipment.ApparatusView
  alias Sportipedia.Catalog.Equipment.Apparatus.ApparatusReadModel, as: Apparatus

  describe "ApparatusView" do
    test "type/0 returns 'apparatuses'" do
      assert ApparatusView.type() == "apparatuses"
    end

    test "fields/0 returns the expected fields" do
      assert ApparatusView.fields() == [:id, :title, :slug, :description]
    end

    test "path/0 returns the expected path" do
      assert ApparatusView.path() == "catalog/equipment/apparatuses"
    end

    test "render show.json produces JSON:API single document" do
      apparatus = %Apparatus{
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
                 }
               }
             } = result
    end
  end
end
