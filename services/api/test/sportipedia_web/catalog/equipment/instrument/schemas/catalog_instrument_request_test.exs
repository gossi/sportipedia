defmodule SportipediaWeb.Catalog.Equipment.Instrument.Schemas.CatalogInstrumentRequestTest do
  use ExUnit.Case

  alias SportipediaWeb.Catalog.Equipment.Instrument.Schemas.CatalogInstrumentRequest

  @moduletag :unit

  describe "CatalogInstrumentRequest" do
    test "schema/0 has the correct title" do
      assert %{title: "equipment.CatalogInstrumentRequest"} = CatalogInstrumentRequest.schema()
    end

    test "schema has required fields title and slug" do
      schema = CatalogInstrumentRequest.schema()
      assert :title in schema.required
      assert :slug in schema.required
    end

    test "schema has optional description field" do
      schema = CatalogInstrumentRequest.schema()
      assert Map.has_key?(schema.properties, :description)
      assert schema.properties.description.nullable == true
    end
  end
end
