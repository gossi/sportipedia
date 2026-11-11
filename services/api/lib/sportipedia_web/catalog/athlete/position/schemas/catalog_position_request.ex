defmodule SportipediaWeb.Catalog.Athlete.Position.Schemas.CatalogPositionRequest do
  @moduledoc """
  OpenAPI schema for documenting the catalog-position request parameters.
  """
  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the catalog-position request.
  """
  OpenApiSpex.schema(%{
    title: "athlete.CatalogPositionRequest",
    type: :object,
    properties: %{
      title: %OpenApiSpex.Schema{type: :string, description: "Name of the position"},
      slug: %OpenApiSpex.Schema{
        type: :string,
        description:
          "URL-friendly identifier of the position itself (raw, not namespaced; the read model stores it as raw_slug and derives the globally unique slug from it and the referenced equipment's slug)"
      },
      apparatusId: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "Reference to apparatus (optional, mutually exclusive with instrumentId)"
      },
      description: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "Optional description"
      },
      instrumentId: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "Reference to instrument (optional, mutually exclusive with apparatusId)"
      }
    },
    required: [:title, :slug]
  })
end
