defmodule SportipediaWeb.Catalog.Equipment.Apparatus.Schemas.ListApparatusesQueryParamsTest do
  use ExUnit.Case

  alias SportipediaWeb.Catalog.Equipment.Apparatus.Schemas.ListApparatusesQueryParams

  describe "ListApparatusesQueryParams" do
    test "schema/0 has the correct title" do
      assert %{title: "equipment.ListApparatusesQueryParams"} =
               ListApparatusesQueryParams.schema()
    end

    test "schema has filter, sort, page, and fields properties" do
      schema = ListApparatusesQueryParams.schema()
      props = schema.properties

      assert Map.has_key?(props, :filter)
      assert Map.has_key?(props, :sort)
      assert Map.has_key?(props, :page)
      assert Map.has_key?(props, :fields)
    end

    test "filter has title property" do
      schema = ListApparatusesQueryParams.schema()
      filter_props = schema.properties.filter.properties

      assert Map.has_key?(filter_props, :title)
    end

    test "sort enum only allows title sorting" do
      schema = ListApparatusesQueryParams.schema()
      sort_schema = schema.properties.sort

      assert sort_schema.enum == ["title", "-title"]
    end

    test "fields enum uses strings, not atoms" do
      schema = ListApparatusesQueryParams.schema()
      fields_schema = schema.properties.fields.properties.apparatus

      assert fields_schema.enum == ["title", "slug", "description"]
    end
  end
end
