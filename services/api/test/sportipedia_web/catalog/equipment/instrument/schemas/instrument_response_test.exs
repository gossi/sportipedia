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

    test "attributes contain title, slug, and description" do
      schema = InstrumentResponse.schema()
      attrs = schema.properties.data.properties.attributes.properties

      assert Map.has_key?(attrs, :title)
      assert attrs.title.type == :string

      assert Map.has_key?(attrs, :slug)
      assert attrs.slug.type == :string

      assert Map.has_key?(attrs, :description)
      assert attrs.description.type == :string
    end
  end
end
