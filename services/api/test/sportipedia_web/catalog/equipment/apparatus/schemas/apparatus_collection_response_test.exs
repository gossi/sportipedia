defmodule SportipediaWeb.Catalog.Equipment.Apparatus.Schemas.ApparatusCollectionResponseTest do
  use ExUnit.Case

  alias SportipediaWeb.Catalog.Equipment.Apparatus.Schemas.ApparatusCollectionResponse

  describe "ApparatusCollectionResponse" do
    test "schema/0 has the correct title" do
      assert %{title: "equipment.Apparatuses"} = ApparatusCollectionResponse.schema()
    end

    test "schema has data as an array" do
      schema = ApparatusCollectionResponse.schema()
      assert schema.properties.data.type == :array
    end
  end
end
