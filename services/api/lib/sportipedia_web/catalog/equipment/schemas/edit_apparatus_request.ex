defmodule SportipediaWeb.Catalog.Equipment.Schemas.EditApparatusRequest do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "equipment.EditApparatusRequest",
    description: "Request body for editing an apparatus",
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          id: %OpenApiSpex.Schema{type: :string, description: "Apparatus ID"},
          type: %OpenApiSpex.Schema{type: :string, enum: ["apparatuses"]},
          attributes: %OpenApiSpex.Schema{
            type: :object,
            description: "Apparatus attributes to update",
            properties: %{
              title: %OpenApiSpex.Schema{type: :string, description: "Name of the apparatus"},
              slug: %OpenApiSpex.Schema{type: :string, description: "URL-friendly unique identifier"},
              description: %OpenApiSpex.Schema{type: :string, description: "Optional description"}
            }
          }
        },
        required: [:id, :type]
      }
    },
    required: [:data]
  })
end
