defmodule SportipediaWeb.Catalog.Equipment.Schemas.ArchiveApparatusRequest do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "equipment.ArchiveApparatusRequest",
    description: "Request body for archiving an apparatus",
    type: :object,
    properties: %{
      data: %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          id: %OpenApiSpex.Schema{type: :string, description: "Apparatus ID"},
          type: %OpenApiSpex.Schema{type: :string, enum: ["apparatuses"]}
        },
        required: [:id, :type]
      }
    },
    required: [:data]
  })
end
