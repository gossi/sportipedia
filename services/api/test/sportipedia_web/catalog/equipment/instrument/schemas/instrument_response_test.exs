defmodule SportipediaWeb.Catalog.Equipment.Instrument.Schemas.InstrumentResponseTest do
  use ExUnit.Case

  alias SportipediaWeb.Catalog.Equipment.Instrument.Schemas.InstrumentResponse

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
end
