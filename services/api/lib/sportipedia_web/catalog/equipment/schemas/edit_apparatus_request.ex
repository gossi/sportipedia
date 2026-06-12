defmodule SportipediaWeb.Catalog.Equipment.Schemas.EditApparatusRequest do
  @moduledoc """
  OpenAPI schema for documenting the edit-apparatus request parameters.
  """

  require OpenApiSpex

  @doc """
  Returns the OpenAPI schema for the edit-apparatus request.
  """
  OpenApiSpex.schema(%{
    title: "equipment.EditApparatusRequest",
    type: :object,
    properties: %{
      title: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "Name of the apparatus"
      },
      slug: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "URL-friendly unique identifier"
      },
      description: %OpenApiSpex.Schema{
        type: :string,
        nullable: true,
        description: "Optional description"
      }
    }
  })
end
