defmodule SportipediaWeb.Catalog.Equipment.Instrument.Schemas.ListInstrumentsQueryParamsTest do
  use ExUnit.Case

  alias SportipediaWeb.Catalog.Equipment.Instrument.Schemas.ListInstrumentsQueryParams

  @moduletag :unit

  describe "ListInstrumentsQueryParams" do
    test "schema/0 has the correct title" do
      assert %{title: "equipment.ListInstrumentsQueryParams"} =
               ListInstrumentsQueryParams.schema()
    end

    test "has filter property with title filter" do
      schema = ListInstrumentsQueryParams.schema()
      filter = schema.properties.filter
      assert filter.type == :object
      assert Map.has_key?(filter.properties, :title)
      assert filter.properties.title.type == :string
    end

    test "has sort property with title enum" do
      schema = ListInstrumentsQueryParams.schema()
      assert schema.properties.sort.type == :string
      assert "title" in schema.properties.sort.enum
      assert "-title" in schema.properties.sort.enum
    end

    test "has page property with number and size" do
      schema = ListInstrumentsQueryParams.schema()
      page = schema.properties.page
      assert page.type == :object
      assert page.properties.number.type == :integer
      assert page.properties.size.type == :integer
      assert page.properties.number.default == 1
      assert page.properties.size.default == 20
    end

    test "has fields property with instrument enum" do
      schema = ListInstrumentsQueryParams.schema()
      fields = schema.properties.fields
      assert fields.type == :object
      assert Map.has_key?(fields.properties, :instrument)
      assert :title in fields.properties.instrument.enum
      assert :slug in fields.properties.instrument.enum
      assert :description in fields.properties.instrument.enum
    end
  end
end
