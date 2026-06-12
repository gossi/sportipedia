defmodule SportipediaWeb.Catalog.Equipment.Schemas.EditApparatusRequestTest do
  use ExUnit.Case

  alias SportipediaWeb.Catalog.Equipment.Schemas.EditApparatusRequest

  describe "EditApparatusRequest" do
    test "schema has the correct title" do
      assert %{title: "equipment.EditApparatusRequest"} = EditApparatusRequest.schema()
    end

    test "schema has optional title, slug, and description properties" do
      schema = EditApparatusRequest.schema()
      props = schema.properties

      assert Map.has_key?(props, :title)
      assert Map.has_key?(props, :slug)
      assert Map.has_key?(props, :description)
    end

    test "schema has no required fields" do
      schema = EditApparatusRequest.schema()
      assert schema.required in [nil, []]
    end
  end
end
