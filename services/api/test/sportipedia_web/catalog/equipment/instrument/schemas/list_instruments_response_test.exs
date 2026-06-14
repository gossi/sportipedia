defmodule SportipediaWeb.Catalog.Equipment.Instrument.Schemas.ListInstrumentsResponseTest do
  use ExUnit.Case

  alias SportipediaWeb.Catalog.Equipment.Instrument.Schemas.ListInstrumentsResponse

  @moduletag :unit

  describe "ListInstrumentsResponse" do
    test "schema/0 has the correct title" do
      assert %{title: "equipment.Instruments"} = ListInstrumentsResponse.schema()
    end

    test "schema has data as an array" do
      schema = ListInstrumentsResponse.schema()
      assert schema.properties.data.type == :array
    end

    test "data array items have instrument attributes" do
      schema = ListInstrumentsResponse.schema()
      item_schema = schema.properties.data.items
      assert Map.has_key?(item_schema.properties, :id)
      assert Map.has_key?(item_schema.properties, :type)
      assert Map.has_key?(item_schema.properties, :attributes)
      assert item_schema.properties.attributes.properties.title.type == :string
      assert item_schema.properties.attributes.properties.slug.type == :string
    end
  end
end
