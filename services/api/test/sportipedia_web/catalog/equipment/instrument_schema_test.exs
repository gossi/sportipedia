defmodule SportipediaWeb.Catalog.Equipment.InstrumentSchemaTest do
  use ExUnit.Case

  alias SportipediaWeb.Catalog.Equipment.Schemas.InstrumentResponse
  alias SportipediaWeb.Catalog.Equipment.Schemas.InstrumentListResponse

  @moduletag :unit

  describe "InstrumentResponse" do
    test "schema/0 has the correct title" do
      assert %{title: "equipment.Instrument"} = InstrumentResponse.schema()
    end

    test "schema has data with id, type, and attributes" do
      schema = InstrumentResponse.schema()
      data_props = schema.properties.data.properties

      assert Map.has_key?(data_props, :id)
      assert Map.has_key?(data_props, :type)
      assert Map.has_key?(data_props, :attributes)
    end
  end

  describe "InstrumentListResponse" do
    test "schema/0 has the correct title" do
      assert %{title: "equipment.Instruments"} = InstrumentListResponse.schema()
    end

    test "schema has data as an array" do
      schema = InstrumentListResponse.schema()

      assert schema.properties.data.type == :array
    end
  end
end
