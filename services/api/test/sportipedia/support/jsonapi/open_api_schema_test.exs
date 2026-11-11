defmodule Sportipedia.Support.JSONAPI.OpenApiSchemaTest do
  use ExUnit.Case

  alias OpenApiSpex.Schema
  alias Sportipedia.Support.JSONAPI.OpenApiSchema
  alias SportipediaWeb.Catalog.Athlete.Position.PositionView

  @params OpenApiSchema.query_params(PositionView,
            title: "athlete.ListPositionsQueryParams",
            filter: [title: "Filter positions by title (partial match)"],
            sort: ~w(title slug)
          )

  describe "query_params/2" do
    test "is an object carrying the title the operation names" do
      assert %{title: "athlete.ListPositionsQueryParams", type: :object} = @params
    end

    test "documents a filter member per filterable field, with its description" do
      assert %Schema{type: :object, properties: %{title: filter}} = @params.properties.filter

      assert %Schema{type: :string, description: "Filter positions by title (partial match)"} =
               filter
    end

    test "documents each sortable field in both directions" do
      assert %Schema{
               type: :string,
               description: "Comma-separated fields to sort by. Prefix with `-` for descending.",
               enum: ["title", "-title", "slug", "-slug"]
             } = @params.properties.sort
    end

    test "paginates by page number and size, the style the QueryBuilder defaults to" do
      assert %Schema{
               type: :object,
               properties: %{
                 number: %Schema{type: :integer, default: 1},
                 size: %Schema{type: :integer, default: 20}
               }
             } = @params.properties.page
    end

    test "the offset style documents the offsets the QueryBuilder reads" do
      offset =
        OpenApiSchema.query_params(PositionView,
          title: "x",
          page: :offset
        )

      assert %Schema{
               type: :object,
               properties: %{
                 limit: %Schema{type: :integer, default: 20},
                 offset: %Schema{type: :integer, default: 0}
               }
             } = offset.properties.page
    end

    test "the sparse fieldset is the view's own fields, keyed by its own type" do
      assert %Schema{
               type: :object,
               properties: %{
                 position: %Schema{
                   type: :string,
                   description: "Comma-separated fields to include in the response",
                   enum: enum
                 }
               }
             } = @params.properties.fields

      # the parameter is a comma-separated *string*, so its enum holds strings —
      # one value per name the view offers
      assert enum == Enum.map(PositionView.fields(), &to_string/1)
    end

    test "what the model names nothing for is not documented" do
      bare = OpenApiSchema.query_params(PositionView, title: "bare", page: :none)

      # filter and sort are the model's to name; the sparse fieldset the view
      # already states, so it stands even in the barest call
      assert %{fields: %Schema{}} = bare.properties
      refute Map.has_key?(bare.properties, :filter)
      refute Map.has_key?(bare.properties, :sort)
      refute Map.has_key?(bare.properties, :page)
    end

    test "a page of `:none` leaves no page member" do
      params = OpenApiSchema.query_params(PositionView, title: "x", sort: ~w(slug), page: :none)

      refute Map.has_key?(params.properties, :page)
      assert %Schema{enum: ["slug", "-slug"]} = params.properties.sort
    end
  end
end
