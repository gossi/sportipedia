defmodule SportipediaWeb.Catalog.Equipment.Apparatus.Schemas.CatalogApparatusRequest do
  @moduledoc """
  OpenAPI schema for documenting the catalog-apparatus request parameters.
  """

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the catalog-apparatus request.
  """
  OpenApiSpex.schema(%{
    title: "equipment.CatalogApparatusRequest",
    type: :object,
    properties: %{
      title: %OpenApiSpex.Schema{type: :string, description: "Name of the apparatus"},
      slug: %OpenApiSpex.Schema{
        type: :string,
        description: "URL-friendly unique identifier"
      },
      description: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "Optional description"
      }
    },
    required: [:title, :slug]
  })
end
