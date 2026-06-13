defmodule SportipediaWeb.Catalog.Equipment.Apparatus.Schemas.CatalogApparatusRequestTest do
  use ExUnit.Case

  alias SportipediaWeb.Catalog.Equipment.Apparatus.Schemas.CatalogApparatusRequest

  describe "CatalogApparatusRequest" do
    test "schema/0 has the correct title" do
      assert %{title: "equipment.CatalogApparatusRequest"} =
               CatalogApparatusRequest.schema()
    end

    test "schema has title, slug, and description properties" do
      schema = CatalogApparatusRequest.schema()
      assert Map.has_key?(schema.properties, :title)
      assert Map.has_key?(schema.properties, :slug)
      assert Map.has_key?(schema.properties, :description)
    end

    test "title and slug are required" do
      schema = CatalogApparatusRequest.schema()
      assert :title in schema.required
      assert :slug in schema.required
    end

    test "description is nullable" do
      schema = CatalogApparatusRequest.schema()
      assert schema.properties.description.nullable == true
    end
  end
end
