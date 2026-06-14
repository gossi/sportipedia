defmodule SportipediaWeb.Catalog.Equipment.Instrument.Schemas.ArchiveInstrumentRequestTest do
  use ExUnit.Case

  alias SportipediaWeb.Catalog.Equipment.Instrument.Schemas.ArchiveInstrumentRequest

  @moduletag :unit

  describe "ArchiveInstrumentRequest" do
    test "schema/0 has the correct title" do
      assert %{title: "equipment.ArchiveInstrumentRequest"} = ArchiveInstrumentRequest.schema()
    end

    test "schema has id as required property" do
      schema = ArchiveInstrumentRequest.schema()
      assert :id in schema.required
      assert Map.has_key?(schema.properties, :id)
      assert schema.properties.id.type == :string
    end
  end
end
