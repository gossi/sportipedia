defmodule SportipediaWeb.Catalog.Equipment.Instrument.Schemas.EditInstrumentRequestTest do
  use ExUnit.Case

  alias SportipediaWeb.Catalog.Equipment.Instrument.Schemas.EditInstrumentRequest

  @moduletag :unit

  describe "EditInstrumentRequest" do
    test "schema/0 has the correct title" do
      assert %{title: "equipment.EditInstrumentRequest"} = EditInstrumentRequest.schema()
    end

    test "schema has the expected properties" do
      schema = EditInstrumentRequest.schema()
      assert Map.has_key?(schema.properties, :id)
      assert Map.has_key?(schema.properties, :title)
      assert Map.has_key?(schema.properties, :slug)
      assert Map.has_key?(schema.properties, :description)
    end

    test "id is required" do
      schema = EditInstrumentRequest.schema()
      assert :id in schema.required
    end
  end
end
