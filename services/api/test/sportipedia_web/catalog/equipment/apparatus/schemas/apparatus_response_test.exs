defmodule SportipediaWeb.Catalog.Equipment.Apparatus.Schemas.ApparatusResponseTest do
  use ExUnit.Case

  alias SportipediaWeb.Catalog.Equipment.Apparatus.Schemas.ApparatusResponse

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
end
