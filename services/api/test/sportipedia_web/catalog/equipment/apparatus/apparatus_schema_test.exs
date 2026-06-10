defmodule SportipediaWeb.Catalog.Equipment.ApparatusSchemaTest do
  use ExUnit.Case

  alias SportipediaWeb.Catalog.Equipment.Schemas.ApparatusResponse
  alias SportipediaWeb.Catalog.Equipment.Schemas.ListApparatusesResponse

  describe "ApparatusResponse" do
    test "schema/0 has the correct title" do
      assert %{title: "equipment.Apparatus"} = ApparatusResponse.schema()
    end

    test "schema has data with id, type, and attributes" do
      schema = ApparatusResponse.schema()
      data_props = schema.properties.data.properties
      assert Map.has_key?(data_props, :id)
      assert Map.has_key?(data_props, :type)
      assert Map.has_key?(data_props, :attributes)
    end
  end

  describe "ListApparatusesResponse" do
    test "schema/0 has the correct title" do
      assert %{title: "equipment.Apparatuses"} = ListApparatusesResponse.schema()
    end

    test "schema has data as array with id, type, and attributes" do
      schema = ListApparatusesResponse.schema()
      data_props = schema.properties.data.items.properties
      assert Map.has_key?(data_props, :id)
      assert Map.has_key?(data_props, :type)
      assert Map.has_key?(data_props, :attributes)
    end
  end
end
