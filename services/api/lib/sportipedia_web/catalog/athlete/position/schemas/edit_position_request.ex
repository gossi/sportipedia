defmodule SportipediaWeb.Catalog.Athlete.Position.Schemas.EditPositionRequest do
  @moduledoc """
  OpenAPI schema for documenting the edit-position request parameters.
  """
  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the edit-position request.
  """
  OpenApiSpex.schema(%{
    title: "athlete.EditPositionRequest",
    type: :object,
    properties: %{
      id: %OpenApiSpex.Schema{
        type: :string,
        description: "Unique identifier of the position to edit"
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
      },
      slug: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description:
          "URL-friendly identifier of the position itself (raw, not namespaced; the read model stores it as raw_slug and re-derives the globally unique slug from it and the referenced equipment's slug)"
      },
      title: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "Name of the position"
      }
    },
    required: [:id]
  })
end
